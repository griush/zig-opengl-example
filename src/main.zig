const glfw = @import("glfw");
const gl = @import("gl");
const zm = @import("zm");
const std = @import("std");

var gl_procs: gl.ProcTable = undefined;

const default_shader_vert_src =
    \\#version 450 core
    \\layout (location = 0) in vec3 a_Position;
    \\
    \\out vec3 v_Position;
    \\uniform mat4 u_Projection;
    \\uniform mat4 u_View;
    \\uniform mat4 u_Model;
    \\
    \\void main() {
    \\  v_Position = a_Position;
    \\  gl_Position = u_Projection * u_View * u_Model * vec4(a_Position, 1.0);
    \\}
;

const default_shader_frag_src =
    \\#version 450 core
    \\layout (location = 0) out vec4 o_Color;
    \\in vec3 v_Position;
    \\uniform vec3 u_Tint;
    \\void main() {
    \\  o_Color = vec4(v_Position + 0.5 + u_Tint, 1.0);
    \\}
;

fn glDebugCallback(source: c_uint, t: c_uint, id: c_uint, severity: c_uint, length: c_int, message: [*:0]const u8, user_param: ?*const anyopaque) callconv(.C) void {
    _ = user_param; // autofix
    _ = length; // autofix
    _ = t; // autofix
    _ = source; // autofix
    switch (severity) {
        gl.DEBUG_SEVERITY_HIGH => std.log.err("Error({d}): {s}", .{ id, message }),
        gl.DEBUG_SEVERITY_MEDIUM => std.log.err("Error({d}): {s}", .{ id, message }),
        gl.DEBUG_SEVERITY_LOW => std.log.warn("Warn({d}): {s}", .{ id, message }),
        gl.DEBUG_SEVERITY_NOTIFICATION => std.log.info("Info({d}): {s}", .{ id, message }),
        else => unreachable,
    }
}

pub fn main() !void {
    const status = glfw.init(.{});
    if (!status) {
        @panic("Could not initialize GLFW!");
    }
    defer glfw.terminate();

    const window = glfw.Window.create(1280, 720, "GLFW/OpenGL example using zm", null, null, .{});
    defer window.?.destroy();

    glfw.makeContextCurrent(window);

    if (!gl_procs.init(glfw.getProcAddress)) {
        @panic("could not get glproc");
    }
    gl.makeProcTableCurrent(&gl_procs);

    gl.Enable(gl.DEBUG_OUTPUT);
    gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS);

    gl.DebugMessageCallback(glDebugCallback, null);

    gl.Enable(gl.DEPTH_TEST);

    glfw.swapInterval(1);

    // Create OpenGL shaders
    const vert: c_uint = gl.CreateShader(gl.VERTEX_SHADER);
    gl.ShaderSource(vert, 1, @ptrCast(&default_shader_vert_src), null);
    gl.CompileShader(vert);

    const frag: c_uint = gl.CreateShader(gl.FRAGMENT_SHADER);
    gl.ShaderSource(frag, 1, @ptrCast(&default_shader_frag_src), null);
    gl.CompileShader(frag);

    const program = gl.CreateProgram();
    gl.AttachShader(program, vert);
    gl.AttachShader(program, frag);
    gl.LinkProgram(program);

    gl.DeleteShader(vert);
    gl.DeleteShader(frag);

    gl.UseProgram(program);

    const vertices = [_]f32{
        // Front face
        -0.5, -0.5, 0.5, // bottom left
        0.5, -0.5, 0.5, // bottom right
        0.5, 0.5, 0.5, // top right
        0.5, 0.5, 0.5, // top right
        -0.5, 0.5, 0.5, // top left
        -0.5, -0.5, 0.5, // bottom left

        // Back face
        -0.5, -0.5, -0.5, // bottom left
        0.5, -0.5, -0.5, // bottom right
        0.5, 0.5, -0.5, // top right
        0.5, 0.5, -0.5, // top right
        -0.5, 0.5, -0.5, // top left
        -0.5, -0.5, -0.5, // bottom left

        // Left face
        -0.5, 0.5, 0.5, // top right
        -0.5, 0.5, -0.5, // top left
        -0.5, -0.5, -0.5, // bottom left
        -0.5, -0.5, -0.5, // bottom left
        -0.5, -0.5, 0.5, // bottom right
        -0.5, 0.5, 0.5, // top right

        // Right face
        0.5, 0.5, 0.5, // top left
        0.5, 0.5, -0.5, // top right
        0.5, -0.5, -0.5, // bottom right
        0.5, -0.5, -0.5, // bottom right
        0.5, -0.5, 0.5, // bottom left
        0.5, 0.5, 0.5, // top left

        // Top face
        -0.5, 0.5, -0.5, // bottom left
        0.5, 0.5, -0.5, // bottom right
        0.5, 0.5, 0.5, // top right
        0.5, 0.5, 0.5, // top right
        -0.5, 0.5, 0.5, // top left
        -0.5, 0.5, -0.5, // bottom left

        // Bottom face
        -0.5, -0.5, -0.5, // top right
        0.5, -0.5, -0.5, // top left
        0.5, -0.5, 0.5, // bottom left
        0.5, -0.5, 0.5, // bottom left
        -0.5, -0.5, 0.5, // bottom right
        -0.5, -0.5, -0.5, // top right;
    };

    var vao: c_uint = undefined;
    gl.CreateVertexArrays(1, (&vao)[0..1]);
    gl.BindVertexArray(vao);

    var vbo: c_uint = undefined;
    gl.CreateBuffers(1, (&vbo)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(f32) * 3, 0);

    var t_rotation: f32 = 0.0;
    var direction: bool = false; // false => camera gets away, true => camera gets closer

    while (!window.?.shouldClose()) {
        switch (direction) {
            true => {
                t_rotation += 0.02;
                if (t_rotation > 1.5) direction = false;
            },
            false => {
                t_rotation -= 0.02;
                if (t_rotation < -0.5) direction = true;
            },
        }

        gl.ClearColor(0.0, 0.0, 0.0, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const tint = zm.Vec3.from(.{ 0.0, 0.0, 0.0 });

        const proj = zm.Mat4.perspective(zm.toRadians(55.0), 16.0 / 9.0, 0.05, 100.0);
        const view = zm.Mat4.lookAt(zm.Vec3.from(.{ 3, 3, 3 }), zm.Vec3.zero(), zm.Vec3.up());

        const rotation1 = zm.Quaternion.fromEulerAngles(zm.Vec3.from(.{ 0.0, 0.0, 0.0 }));
        const rotation2 = zm.Quaternion.fromEulerAngles(zm.Vec3.from(.{ zm.toRadians(90.0), 0.0, zm.toRadians(90.0) }));
        const model = zm.Mat4.fromQuaternion(zm.Quaternion.slerp(rotation1, rotation2, t_rotation)).multiply(zm.Mat4.scaling(1.5, 1.5, 1.5));

        const tint_loc = gl.GetUniformLocation(program, "u_Tint");
        gl.Uniform3f(tint_loc, tint.x(), tint.y(), tint.z());

        const proj_loc = gl.GetUniformLocation(program, "u_Projection");
        // transposition needed in OpenGL
        gl.UniformMatrix4fv(proj_loc, 1, gl.TRUE, @ptrCast(&(proj)));

        const view_loc = gl.GetUniformLocation(program, "u_View");
        // transposition needed in OpenGL
        const v = view;
        gl.UniformMatrix4fv(view_loc, 1, gl.TRUE, @ptrCast(&(v)));

        const model_loc = gl.GetUniformLocation(program, "u_Model");
        // transposition needed in OpenGL
        gl.UniformMatrix4fv(model_loc, 1, gl.TRUE, @ptrCast(&(model)));

        gl.DrawArrays(gl.TRIANGLES, 0, vertices.len / 3);

        window.?.swapBuffers();
        glfw.pollEvents();
    }
}
