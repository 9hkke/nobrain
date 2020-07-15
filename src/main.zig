pub fn main() void {
    comptime var ret = compileBrainfuck("default.bf", 16);
    const print = @import("std").debug.print;
    
    print("Output: {}\nCycles done: {}\nTape: ", .{
        ret.value.buffer,
        ret.value.runtime,
    });
    inline for (ret.value.tape) |te| print("{} ", .{te});
    print("\n", .{});
}

/// Compile Brainfuck file to a State object, containing all computations done.
/// This is to aid with optimization in a future.
fn compileBrainfuck(comptime fname: []const u8, comptime tape_size: usize) State(Machine(tape_size)) {
    return comptime blk: {
        const ST = State(Machine(tape_size));
        var state = ST.create(Machine(tape_size){
            .runtime = 0,
            .codeptr = 0,
            .tape = [_]u8{0} ** tape_size,
            .pointer = 0,
            .callstack = Stack(8, usize).init(0),
            .buffer = "",
        });

        const file = @embedFile(fname);
        @setEvalBranchQuota(10000);

        inline while (state.value.codeptr < file.len) {
            state = comptimeParse(Machine(tape_size), state, file[state.value.codeptr]);
        }

        break :blk state;
    };
}

/// Parse Brainfuck instruction at compile-time.
/// Receives a State object, and a character representing the instruction.
/// Returns a new State object referencing the old one.
fn comptimeParse(comptime T: type, comptime state: State(T), comptime char: u8) !State(T) {
    var tape = state.value.tape;
    var pointer = state.value.pointer;
    var callstack = state.value.callstack;
    var buffer = state.value.buffer;
    var codeptr = state.value.codeptr;
    var runtime = state.value.runtime;

    switch (char) {
        '+' => {
            tape[pointer] += 1;
            codeptr += 1;
        },
        '-' => {
            tape[pointer] -= 1;
            codeptr += 1;
        },
        '>' => {
            pointer += 1;
            codeptr += 1;
        },
        '<' => {
            pointer -= 1;
            codeptr += 1;
        },
        '[' => {
            callstack.push(codeptr);
            codeptr += 1;
        },
        ']' => {
            if (tape[pointer] != 0) {
                codeptr = callstack.pop();
            } else {
                codeptr += 1;
            }
        },
        '.' => {
            buffer = buffer ++ [_]u8{tape[pointer]};
            codeptr += 1;
        },
        ',' => {
            return error.Unavail;
        },
        else => {
            codeptr += 1;
        },
    }

    return State(T){
        .old_state = &state,
        .value = T{
            .runtime = runtime + 1,
            .codeptr = codeptr,
            .tape = tape,
            .pointer = pointer,
            .callstack = callstack,
            .buffer = buffer,
        },
    };
}

fn Machine(comptime s: usize) type {
    return struct {
        const Self = @This();
        runtime: usize,
        codeptr: usize,
        tape: [s]u8,
        pointer: usize,
        callstack: Stack(8, usize),
        buffer: []const u8
    };
}
fn Stack(comptime s: usize, comptime T: type) type {
    return struct {
        const Self = @This();
        items: [s]T,
        pointer: usize,

        pub fn init(comptime v: T) Self {
            return Self{
                .items = [_]T{v} ** s,
                .pointer = 0,
            };
        }

        pub fn push(self: *Self, value: T) void {
            self.items[self.pointer] = value;
            self.pointer += 1;
        }

        pub fn pop(self: *Self) T {
            self.pointer -= 1;
            return self.items[self.pointer];
        }
    };
}
fn State(comptime T: type) type {
    return struct {
        const Self = @This();
        old_state: ?*const Self,
        value: T,

        pub fn create(comptime value: T) Self {
            return Self{
                .old_state = null,
                .value = value,
            };
        }
    };
}
