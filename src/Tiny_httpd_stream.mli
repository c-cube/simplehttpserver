(** Byte streams.

    Streams are used to represent a series of bytes that can arrive progressively.
    For example, an uploaded file will be sent as a series of chunks.

    These used to live in {!Tiny_httpd} but are now in their own module.
    @since 0.12 *)

type hidden
(** Type used to make {!t} unbuildable via a record literal. Use {!make} instead. *)

type t = {
  mutable bs: bytes;  (** The bytes *)
  mutable off: int;  (** Beginning of valid slice in {!bs} *)
  mutable len: int;
      (** Length of valid slice in {!bs}. If [len = 0] after
      a call to {!fill}, then the stream is finished. *)
  fill_buf: unit -> unit;
      (** See the current slice of the internal buffer as [bytes, i, len],
      where the slice is [bytes[i] .. [bytes[i+len-1]]].
      Can block to refill the buffer if there is currently no content.
      If [len=0] then there is no more data. *)
  consume: int -> unit;
      (** Consume [n] bytes from the buffer.
      This should only be called with [n <= len]. *)
  close: unit -> unit;  (** Close the stream. *)
  _rest: hidden;  (** Use {!make} to build a stream. *)
}
(** A buffered stream, with a view into the current buffer (or refill if empty),
    and a function to consume [n] bytes.

    The point of this type is that it gives the caller access to its internal buffer
    ([bs], with the slice [off,len]). This is convenient for things like line
    reading where one needs to peek ahead.

    Some core invariant for this type of stream are:
      - [off,len] delimits a valid slice in [bs] (indices: [off, off+1, … off+len-1])
      - if [fill_buf()] was just called, then either [len=0] which indicates the end
        of stream; or [len>0] and the slice contains some data.

    To actually move forward in the stream, you can call [consume n]
    to consume [n] bytes (where [n <= len]). If [len] gets to [0], calling
    [fill_buf()] is required, so it can try to obtain a new slice.

    To emulate a classic OCaml reader with a [read: bytes -> int -> int -> int] function,
    the simplest is:

    {[
    let read (self:t) buf offset max_len : int =
      self.fill_buf();
      let len = min max_len self.len in
      if len > 0 then (
        Bytes.blit self.bs self.off buf offset len;
        self.consume len;
      );
      len

    ]}
*)

val close : t -> unit
(** Close stream *)

val empty : t
(** Stream with 0 bytes inside *)

val of_input : ?buf_size:int -> Tiny_httpd_io.Input.t -> t
(** Make a buffered stream from the given channel.
    @since 0.14 *)

val of_chan : ?buf_size:int -> in_channel -> t
(** Make a buffered stream from the given channel. *)

val of_chan_close_noerr : ?buf_size:int -> in_channel -> t
(** Same as {!of_chan} but the [close] method will never fail. *)

val of_fd : ?buf_size:int -> closed:bool ref -> Unix.file_descr -> t
(** Make a buffered stream from the given file descriptor. *)

val of_fd_close_noerr : ?buf_size:int -> closed:bool ref -> Unix.file_descr -> t
(** Same as {!of_fd} but the [close] method will never fail. *)

val of_bytes : ?i:int -> ?len:int -> bytes -> t
(** A stream that just returns the slice of bytes starting from [i]
    and of length [len]. *)

val of_string : string -> t

val iter : (bytes -> int -> int -> unit) -> t -> unit
(** Iterate on the chunks of the stream
    @since 0.3 *)

val to_chan : out_channel -> t -> unit
(** Write the stream to the channel.
    @since 0.3 *)

val to_chan' : Tiny_httpd_io.Output.t -> t -> unit
(** Write to the IO channel.
    @since 0.14 *)

val to_writer : t -> Tiny_httpd_io.Writer.t
(** Turn this stream into a writer.
    @since 0.14 *)

val make :
  ?bs:bytes ->
  ?close:(t -> unit) ->
  consume:(t -> int -> unit) ->
  fill:(t -> unit) ->
  unit ->
  t
(** [make ~fill ()] creates a byte stream.
    @param fill is used to refill the buffer, and is called initially.
    @param close optional closing.
    @param init_size size of the buffer.
*)

val with_file : ?buf_size:int -> string -> (t -> 'a) -> 'a
(** Open a file with given name, and obtain an input stream
    on its content. When the function returns, the stream (and file) are closed. *)

val read_line : ?buf:Tiny_httpd_buf.t -> t -> string
(** Read a line from the stream.
    @param buf a buffer to (re)use. Its content will be cleared. *)

val read_all : ?buf:Tiny_httpd_buf.t -> t -> string
(** Read the whole stream into a string.
    @param buf a buffer to (re)use. Its content will be cleared. *)

val limit_size_to :
  close_rec:bool -> max_size:int -> too_big:(int -> unit) -> t -> t
(* New stream with maximum size [max_size].
   @param close_rec if true, closing this will also close the input stream
   @param too_big called with read size if the max size is reached *)

val read_chunked : ?buf:Tiny_httpd_buf.t -> fail:(string -> exn) -> t -> t
(** Convert a stream into a stream of byte chunks using
    the chunked encoding. The size of chunks is not specified.
    @param buf buffer used for intermediate storage.
    @param fail used to build an exception if reading fails.
*)

val read_exactly :
  close_rec:bool -> size:int -> too_short:(int -> unit) -> t -> t
(** [read_exactly ~size bs] returns a new stream that reads exactly
    [size] bytes from [bs], and then closes.
    @param close_rec if true, closing the resulting stream also closes
    [bs]
    @param too_short is called if [bs] closes with still [n] bytes remaining
*)

val output_chunked : ?buf:Tiny_httpd_buf.t -> out_channel -> t -> unit
(** Write the stream into the channel, using the chunked encoding.
    @param buf optional buffer for chunking (since 0.14) *)

val output_chunked' :
  ?buf:Tiny_httpd_buf.t -> Tiny_httpd_io.Output.t -> t -> unit
(** Write the stream into the channel, using the chunked encoding.
    @since 0.14 *)
