const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Options
    const shared = b.option(bool, "shared", "Build the Shared Library [default: false]") orelse false;

    // zon dependency
    const mujoco_dep = b.dependency("mujoco", .{});
    const tinyxml2_dep = b.dependency("tinyxml2", .{});
    const tinyobjloader_dep = b.dependency("tinyobjloader", .{});
    const ccd_dep = b.dependency("ccd", .{});
    const lodepng_dep = b.dependency("lodepng", .{});
    const marchingcubecpp_dep = b.dependency("marchingcubecpp", .{});
    const qhull_dep = b.dependency("qhull", .{});
    const zglfw_dep = b.dependency("zglfw", .{});

    const ccd_config_header = b.addConfigHeader(.{
        .style = .{ .cmake = ccd_dep.path("src/ccd/config.h.cmake.in") },
        .include_path = "ccd/config.h",
    }, .{
        .CCD_SINGLE = 0,
        .CCD_DOUBLE = 1,
    });

    const tinyxml2_lib = b.addLibrary(.{
        .name = "tinyxml2",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
        .linkage = if (shared) .dynamic else .static,
    });
    tinyxml2_lib.addCSourceFiles(.{
        .root = tinyxml2_dep.path(""),
        .files = &.{"tinyxml2.cpp"},
        .language = .cpp,
    });

    const lodepng_lib = b.addLibrary(.{
        .name = "lodepng",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
        .linkage = if (shared) .dynamic else .static,
    });
    lodepng_lib.addCSourceFiles(.{
        .root = lodepng_dep.path(""),
        .files = &.{"lodepng.cpp"},
        .language = .cpp,
    });

    const qhullr_lib = b.addLibrary(.{
        .name = "qhull_r",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
        .linkage = if (shared) .dynamic else .static,
    });
    qhullr_lib.addCSourceFiles(.{
        .root = qhull_dep.path("src/libqhull_r"),
        .files = &.{
            "global_r.c",
            "stat_r.c",
            "geom2_r.c",
            "poly2_r.c",
            "merge_r.c",
            "libqhull_r.c",
            "geom_r.c",
            "poly_r.c",
            "qset_r.c",
            "mem_r.c",
            "random_r.c",
            "usermem_r.c",
            "userprintf_r.c",
            "io_r.c",
            "user_r.c",
            "accessors_r.c",
            "rboxlib_r.c",
            "userprintf_rbox_r.c",
        },
        .language = .cpp,
    });

    const ccd_lib = b.addLibrary(.{
        .name = "ccd",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
        .linkage = if (shared) .dynamic else .static,
    });
    ccd_lib.addCSourceFiles(.{
        .root = ccd_dep.path("src"),
        .files = &.{
            "ccd.c",
            "mpr.c",
            "polytope.c",
            "support.c",
            "vec3.c",
        },
    });
    ccd_lib.addIncludePath(ccd_dep.path("src"));
    ccd_lib.addConfigHeader(ccd_config_header);

    const tinyobjloader_lib = b.addLibrary(.{
        .name = "tinyobjloader",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
        .linkage = if (shared) .dynamic else .static,
    });

    tinyobjloader_lib.addCSourceFiles(.{
        .root = tinyobjloader_dep.path(""),
        .files = &.{"tiny_obj_loader.cc"},
        .language = .cpp,
    });

    const lib = b.addLibrary(.{
        .name = "mujoco",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
        .linkage = if (shared) .dynamic else .static,
        .version = .{
            .major = 3,
            .minor = 3,
            .patch = 4,
        },
    });
    lib.root_module.addCMacro("MC_IMPLEM_ENABLE", "1");
    lib.addIncludePath(mujoco_dep.path("include"));
    lib.addIncludePath(mujoco_dep.path("src"));
    lib.addIncludePath(tinyxml2_dep.path(""));
    lib.addIncludePath(tinyobjloader_dep.path(""));
    lib.addIncludePath(lodepng_dep.path(""));
    lib.addIncludePath(marchingcubecpp_dep.path(""));
    lib.addIncludePath(qhull_dep.path("src/libqhull_r"));
    lib.addConfigHeader(ccd_config_header);
    lib.addIncludePath(ccd_dep.path("src"));
    lib.addCSourceFiles(.{
        .root = mujoco_dep.path("src"),
        .files = xml_srcs ++ user_srcs ++ thread_srcs,
        .language = .cpp,
    });
    lib.addCSourceFiles(.{
        .root = mujoco_dep.path("src"),
        .files = engine_srcs ++ render_srcs,
        .language = .c,
    });
    lib.addCSourceFiles(.{
        .root = mujoco_dep.path("src"),
        .files = ui_srcs,
        .language = .c,
    });

    if (optimize == .Debug or optimize == .ReleaseSafe)
        lib.bundle_compiler_rt = true
    else
        lib.root_module.strip = true;
    if (lib.linkage == .static)
        lib.pie = true;

    lib.installHeadersDirectory(mujoco_dep.path("include"), "", .{});
    lib.linkLibrary(tinyxml2_lib);
    lib.linkLibrary(lodepng_lib);
    lib.linkLibrary(qhullr_lib);
    lib.linkLibrary(ccd_lib);
    lib.linkLibrary(tinyobjloader_lib);
    b.installArtifact(lib);

    // Examples
    const main = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .target = target,
            .link_libcpp = true,
            .root_source_file = b.path("src/main.zig"),
        }),
    });
    main.linkLibrary(lib);
    b.installArtifact(main);

    const basic = b.addExecutable(.{
        .name = "basic",
        .root_module = b.createModule(.{
            .target = target,
            .link_libcpp = true,
        }),
    });
    basic.addCSourceFiles(.{
        .root = mujoco_dep.path("sample"),
        .files = &.{"basic.cc"},
        .language = .cpp,
    });
    if (target.result.os.tag != .emscripten) {
        basic.linkLibrary(zglfw_dep.artifact("glfw"));
    }
    basic.linkLibrary(lib);
    b.installArtifact(basic);

    const simulate = b.addExecutable(.{
        .name = "simulate",
        .root_module = b.createModule(.{
            .target = target,
            .link_libcpp = true,
        }),
    });
    simulate.addCSourceFiles(.{
        .root = mujoco_dep.path("simulate"),
        .files = &.{
            "main.cc",
            "simulate.cc",
            "glfw_adapter.cc",
            "glfw_dispatch.cc",
            "platform_ui_adapter.cc",
        },
        .language = .cpp,
    });
    if (target.result.os.tag != .emscripten) {
        simulate.linkLibrary(zglfw_dep.artifact("glfw"));
    }
    simulate.linkLibrary(lib);
    simulate.linkLibrary(lodepng_lib);
    simulate.addIncludePath(lodepng_dep.path(""));
    b.installArtifact(simulate);
}

const xml_srcs: []const []const u8 = &.{
    "xml/xml_api.cc",
    "xml/xml_base.cc",
    "xml/xml.cc",
    "xml/xml_native_reader.cc",
    "xml/xml_numeric_format.cc",
    "xml/xml_native_writer.cc",
    "xml/xml_urdf.cc",
    "xml/xml_util.cc",
};
const engine_srcs: []const []const u8 = &.{
    "engine/engine_callback.c",
    "engine/engine_collision_box.c",
    "engine/engine_collision_convex.c",
    "engine/engine_collision_driver.c",
    "engine/engine_collision_gjk.c",
    "engine/engine_collision_primitive.c",
    "engine/engine_collision_sdf.c",
    "engine/engine_core_constraint.c",
    "engine/engine_core_smooth.c",
    "engine/engine_crossplatform.cc",
    "engine/engine_derivative.c",
    "engine/engine_derivative_fd.c",
    "engine/engine_forward.c",
    "engine/engine_inverse.c",
    "engine/engine_island.c",
    "engine/engine_io.c",
    "engine/engine_name.c",
    "engine/engine_passive.c",
    "engine/engine_plugin.cc",
    "engine/engine_print.c",
    "engine/engine_ray.c",
    "engine/engine_sensor.c",
    "engine/engine_setconst.c",
    "engine/engine_solver.c",
    "engine/engine_support.c",
    "engine/engine_util_blas.c",
    "engine/engine_util_errmem.c",
    "engine/engine_util_misc.c",
    "engine/engine_util_solve.c",
    "engine/engine_util_sparse.c",
    "engine/engine_util_spatial.c",
    "engine/engine_vis_init.c",
    "engine/engine_vis_interact.c",
    "engine/engine_vis_visualize.c",
};
const user_srcs: []const []const u8 = &.{
    "user/user_api.cc",
    "user/user_cache.cc",
    "user/user_composite.cc",
    "user/user_flexcomp.cc",
    "user/user_init.c",
    "user/user_mesh.cc",
    "user/user_model.cc",
    "user/user_objects.cc",
    "user/user_resource.cc",
    "user/user_util.cc",
    "user/user_vfs.cc",
};
const thread_srcs: []const []const u8 = &.{
    "thread/thread_pool.cc",
    "thread/thread_task.cc",
};

const render_srcs: []const []const u8 = &.{
    "render/glad/glad.c",
    "render/glad/loader.cc",
    "render/render_context.c",
    "render/render_gl2.c",
    "render/render_gl3.c",
    "render/render_util.c",
};

const ui_srcs: []const []const u8 = &.{"ui/ui_main.c"};
