pub const Exception = enum(u8) {
    address_error_load = 4,
    address_error_store = 5,
    syscall = 8,
    break_op = 9,
    coprocessor_unusable = 11,
    overflow = 12,
};
