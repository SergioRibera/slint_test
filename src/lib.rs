use slint::ComponentHandle;

fn ui() -> ui::MainWindow {
    let main_window = ui::MainWindow::new().unwrap();

    virtual_keyboard::init(&main_window);

    main_window
}

pub fn main() {
    ui().run().unwrap();
}

#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
fn android_main(app: slint::android::AndroidApp) {
    slint::android::init(app).unwrap();
    ui().run().unwrap();
}

pub mod virtual_keyboard {
    use ui::*;

    pub fn init(app: &MainWindow) {
        let weak = app.as_weak();
        app.global::<VirtualKeyboardHandler>().on_key_pressed({
            move |key| {
                weak.unwrap()
                    .window()
                    .dispatch_event(slint::platform::WindowEvent::KeyPressed { text: key.clone() });
                weak.unwrap()
                    .window()
                    .dispatch_event(slint::platform::WindowEvent::KeyReleased { text: key });
            }
        });
    }
}
