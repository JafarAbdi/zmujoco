pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <scene.xml>\n", .{args[0]});
        return;
    }

    const scene_file = args[1];

    var error_buffer: [4096]u8 = undefined;
    const model = mj.mj_loadXML(scene_file.ptr, null, @ptrCast(&error_buffer), error_buffer.len) orelse {
        std.debug.print("Failed to load model from {s}: {s}\n", .{ scene_file, error_buffer[0..] });
        return;
    };
    defer mj.mj_deleteModel(model);

    const data = mj.mj_makeData(model) orelse {
        std.debug.print("Failed to create data for model\n", .{});
        return;
    };
    defer mj.mj_deleteData(data);

    std.debug.print("Hello, Mujoco!\n", .{});
    std.debug.print("Model nq: {d}. Data qpos: {any}\n", .{
        model.*.nq,
        data.*.qpos[0..@intCast(model.*.nq)],
    });
    std.debug.print("Model nu: {d}. Data ctrl: {any}\n", .{
        model.*.nu,
        data.*.ctrl[0..@intCast(model.*.nu)],
    });
    for (0..@intCast(model.*.njnt)) |i| {
        const name = getJointName(model, i);
        std.debug.print("Joint {}: {s}\n", .{ i, name });
    }
}

fn getJointName(model: [*c]const mj.mjModel, joint_idx: usize) []const u8 {
    const name_addr = @as(usize, @intCast(model.*.name_jntadr[joint_idx]));
    const name_ptr = model.*.names + name_addr;
    return std.mem.span(name_ptr);
}

const std = @import("std");
const mj = @cImport({
    @cInclude("mujoco/mujoco.h");
});
