package live_reload_demo

using import "core:runtime"
import "core:math"
import "core:os"
import "core:fmt"
import serializer "core:encoding/json"

using import "../../raylib_types"
using import "../../raylib_bridge"

import "./game_math"
using import "./debug_console"

import "./plugin"

State :: struct {
    num_frames : int,
    currentFrame : int,
    framesCounter : int,
    framesSpeed : int,
    position : Vector2,
    cat_x: f32,
    cat_velocity: f32,
}

Transient_State :: struct {
    bg : Texture,
    frameRec : Rectangle,
    bg2 : Texture,
    cat : Texture,
    scarfy : Texture,
    meow : Sound,
    console: Debug_Console,
    did_play: bool,
}

state : State;
transient_state : Transient_State;

@(export)
on_load :: proc(funcs: ^raylib_Funcs) {
    bridge_init(funcs);

    using state;
    using transient_state;

    scarfy = load_texture("resources/scarfy.png");
    cat = load_texture("resources/cat.png");
    meow = load_sound("resources/tanatana.ogg");

    num_frames = 6;
    frameRec = Rectangle { 0, 0, cast(f32)scarfy.width / cast(f32)num_frames, cast(f32)scarfy.height };
    framesSpeed = 9;

    {
        bg_img := gen_image_gradient_v(850, 450, PURPLE, RAYWHITE);
        defer unload_image(bg_img);
        bg = load_texture_from_image(bg_img);

        bg2_img := gen_image_gradient_h(850, 450, Color { 0, 0, 0, 0, }, Color { 255, 190, 200, 60 });
        defer unload_image(bg2_img);

        bg2 = load_texture_from_image(bg2_img);
    }

    debug_console.init(&console);
    debug_console.log(&console, "game.dll loaded at time=", get_time(), " seconds");
}

@(export)
on_unload :: proc() {
    bridge_deinit();

    using state;
    using transient_state;

    if state_bytes, err := serializer.marshal(state); err == .None {
        os.write_entire_file("\\Users\\Kevin\\AppData\\LocalLow\\Temp\\state.cel", state_bytes);
    } else {
        s := "";
        switch err {
            case .Unsupported_Type: s = "Unsupported_Type";
            case: s = "TODO";
        }
        fmt.println_err("error serializing state to bytes: ", s);
    }

    debug_console.destroy(&console);
    unload_texture(scarfy);
    unload_texture(bg);
    unload_texture(bg2);
    unload_sound(meow);
}

@(export)
update_and_draw :: proc() -> plugin.Request {
    using state;
    using transient_state;

    request := plugin.Request.None;

    if !did_play && is_audio_device_ready() {
        //play_sound(meow);
        did_play = true;
    }

    // UPDATE
    width_of_one_frame := cast(f32)scarfy.width / cast(f32)num_frames;
    {
        framesCounter += 1;
        delta_time := get_frame_time();
        player_move_pixels_per_second:f32 = 400.0;
        speed := delta_time * player_move_pixels_per_second;

        // move the player with the arrow or WASD keys
        if is_key_down(.KEY_RIGHT) || is_key_down(.KEY_D) do position.x += speed;
        if is_key_down(.KEY_LEFT) || is_key_down(.KEY_A) do position.x -= speed;
        if is_key_down(.KEY_UP) || is_key_down(.KEY_W) do position.y -= speed;
        if is_key_down(.KEY_DOWN) || is_key_down(.KEY_S) do position.y += speed;

        if is_key_pressed(.KEY_L) do debug_console.log(&console, "this is a test");

        if is_key_pressed(.KEY_R) do request = .Reload;
        if is_key_pressed(.KEY_Q) do request = .Quit;

        // click to move the player as well
        if is_mouse_button_down(.MOUSE_LEFT_BUTTON) {
            mouse_pos := get_mouse_position();
            to_pos := math.length(math.Vec2 { mouse_pos.x - position.x, mouse_pos.y - position.y });
            if to_pos > 20 {
                mouse_pos.x -= f32(width_of_one_frame) * .5;
                mouse_pos.y -= f32(scarfy.height) * .5;
                if mouse_pos.x > position.x do position.x = min(mouse_pos.x, position.x + speed);
                else if mouse_pos.x < position.x do position.x = max(mouse_pos.x, position.x - speed);
                if mouse_pos.y > position.y do position.y = min(mouse_pos.y, position.y + speed);
                else if mouse_pos.y < position.y do position.y = max(mouse_pos.y, position.y - speed);
            }
        }

        // update the player sprite
        if framesCounter >= (60.0 / framesSpeed) {
            framesCounter = 0;
            currentFrame += 1;
            if currentFrame >= num_frames do currentFrame = 0.0;
            frameRec.x = cast(f32)currentFrame * width_of_one_frame;
        }

        // smoothly move the cat towards the player
        smooth_time:f32 = 0.4;

        cat_x = game_math.smooth_damp(cat_x, position.x - 40, &cat_velocity, smooth_time, delta_time);
    }

    player_rect := Rectangle { position.x, position.y, width_of_one_frame, f32(scarfy.height) };
    cat_y:f32 : 230;
    cat_rect := Rectangle { cat_x, cat_y, f32(cat.width), f32(cat.height) };
    cat_color := check_collision_recs(player_rect, cat_rect) ? RED : WHITE;

    // DRAW
    {
        begin_drawing();
        defer end_drawing();

        clear_background(RAYWHITE);
        draw_texture(bg, 0, 0, WHITE);
        {
            begin_blend_mode(BlendMode.BLEND_ADDITIVE);
            defer end_blend_mode();

            draw_texture(bg2, 0, 0, WHITE);
        }

        draw_texture_rec(scarfy, frameRec, position, WHITE);
        draw_texture(cat, cast(i32)cat_x, cast(i32)cat_y, cat_color);
        {
            begin_blend_mode(BlendMode.BLEND_MULTIPLIED);
            defer end_blend_mode();

            draw_circle_v(get_mouse_position(), 15, RED);
        }

        debug_console.update_and_draw(&console);
    }

    return request;
}
