pub const Memory = struct {
    bios: []u8,

    pub fn init(bios: []u8) Memory {
        return Memory{
            .bios = bios,
        };
    }
};