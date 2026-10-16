///|
type Handle

///|
#borrow(data)
extern "C" fn native_new(data : Bytes, len : Int, mode : Int) -> Handle = "lab_buffer_new"

///|
#borrow(handle)
extern "C" fn native_share(handle : Handle) -> Handle = "lab_buffer_share"

///|
#borrow(handle)
extern "C" fn native_close(handle : Handle, mode : Int) -> Unit = "lab_buffer_close"

///|
#borrow(handle)
extern "C" fn native_alive(handle : Handle) -> Int = "lab_buffer_alive"

///|
extern "C" fn native_live() -> Int = "lab_buffer_live"

///|
#borrow(handle)
extern "C" fn native_read(handle : Handle) -> Bytes = "lab_buffer_read"

///|
#borrow(handle)
extern "C" fn native_write(handle : Handle, index : Int, value : Int, mode : Int) -> Int = "lab_buffer_write"

///|
extern "C" fn native_probe(mode : Int) -> Unit = "lab_buffer_probe"
