const glfw = @import("glfw");
const gl = @import("gl");
const zm = @import("zm");

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

pub fn main() !void {
    const status = glfw.init(.{});
    if (!status) {
        @panic("Could not initialize GLFW!");
    }
    defer glfw.terminate();

    const window = glfw.Window.create(1920, 1080, "GLFW/OpenGL example using zm", null, null, .{});
    defer window.?.destroy();

    glfw.makeContextCurrent(window);

    if (!gl_procs.init(glfw.getProcAddress)) {
        @panic("could not get glproc");
    }
    gl.makeProcTableCurrent(&gl_procs);

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
        -0.5, -0.5, 0.0,
        0.5,  -0.5, 0.0,
        0.0,  0.5,  0.0,
    };

    var vao: c_uint = undefined;
    gl.CreateVertexArrays(1, (&vao)[0..1]);
    gl.BindVertexArray(vao);

    var vbo: c_uint = undefined;
    gl.CreateBuffers(1, (&vbo)[0..1]);
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * 3 * 3, &vertices, gl.STATIC_DRAW);

    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, @sizeOf(f32) * 3, 0);

    var z: f32 = -2.0;
    var direction: bool = false; // false => camera gets away, true => camera gets closer
    var rotation: f32 = 0.0;

    while (!window.?.shouldClose()) {
        switch (direction) {
            true => {
                z += 0.04;
                if (z > -1.5) direction = false;
            },
            false => {
                z -= 0.04;
                if (z < -10.0) direction = true;
            },
        }

        rotation += 0.5;

        gl.ClearColor(0.1, 0.1, 0.1, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const tint = zm.Vec3.from(.{ 0.0, 0.0, 1.0 });

        const proj = zm.Mat4.perspective(zm.toRadians(65.0), 16.0 / 9.0, 0.05, 100.0);
        const view = zm.Mat4.translation(0.0, 0.0, z);
        const model = zm.Mat4.rotation(zm.Vec3.forward(), zm.toRadians(rotation));

        const tint_loc = gl.GetUniformLocation(program, "u_Tint");
        gl.Uniform3f(tint_loc, tint.x(), tint.y(), tint.z());

        const proj_loc = gl.GetUniformLocation(program, "u_Projection");
        // transposition needed in OpenGL
        gl.UniformMatrix4fv(proj_loc, 1, gl.FALSE, @ptrCast(&(proj.transpose())));

        const view_loc = gl.GetUniformLocation(program, "u_View");
        // transposition needed in OpenGL
        gl.UniformMatrix4fv(view_loc, 1, gl.FALSE, @ptrCast(&(view.transpose())));

        const model_loc = gl.GetUniformLocation(program, "u_Model");
        // transposition needed in OpenGL
        gl.UniformMatrix4fv(model_loc, 1, gl.FALSE, @ptrCast(&(model.transpose())));

        gl.DrawArrays(gl.TRIANGLES, 0, 3);

        window.?.swapBuffers();
        glfw.pollEvents();
    }
}
