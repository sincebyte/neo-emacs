import asyncio
import threading
import AppKit
from PyObjCTools.AppHelper import callLater, runEventLoop

from Cocoa import (
    NSApplication,
    NSWindow,
    NSRect,
    NSColor,
    NSPoint,
    NSVisualEffectView,
    NSApplicationActivationPolicyRegular,
    NSTextField,
    NSFont,
    NSVisualEffectBlendingModeBehindWindow,
    NSViewWidthSizable,
    NSViewHeightSizable,
    NSApplicationActivationPolicyAccessory,
)


from bleak import BleakClient, BleakError

# 设备的蓝牙地址
DEVICE_ADDRESS = "2A964ADD-92DC-C48F-80AB-6F403EC8A03A"
HEART_RATE_MEASUREMENT_UUID = "2A37"
glabel = None


# 处理接收到的心率通知
def heart_rate_notification_handler(characteristic, data):
    # 假设数据格式是标准的心率测量格式，解析心率值
    if len(data) >= 2:
        heart_rate = data[1]  # 数据的第二个字节是心率值
        global glabel
        callLater(0, glabel.setStringValue_, str(heart_rate))
        # with open("/Users/van/.hr", "w") as f:
        #     f.write(f"{heart_rate}")
    else:
        print("Invalid heart rate data")


# 连接到设备并启动通知
async def run():
    while True:
        try:
            async with BleakClient(DEVICE_ADDRESS) as client:
                # 启动通知
                await client.start_notify(
                    HEART_RATE_MEASUREMENT_UUID, heart_rate_notification_handler
                )
                while client.is_connected:
                    # 保持连接并接收通知
                    await asyncio.sleep(10)
                # 停止通知
                # await client.stop_notify(HEART_RATE_MEASUREMENT_UUID)
        except (BleakError, asyncio.TimeoutError):
            await asyncio.sleep(10)
        except Exception:
            await asyncio.sleep(10)


class DraggableWindow(NSWindow):
    def __init__(self, frame):
        super(DraggableWindow, self).__init__()
        self.setFrame_(frame)
        self.setStringValue_("Drag Me!")
        self.setFont_(NSFont.fontWithName_size_("Helvetica", 24))

        # 初始化鼠标按下时的位置
        self.mouse_initial_pos = None

    def mouseDown_(self, event):
        # 记录鼠标按下的位置
        self.mouse_initial_pos = event.locationInWindow()

    def mouseDragged_(self, event):
        if self.mouse_initial_pos is not None:
            # 获取鼠标拖动的位移，分别计算 x 和 y 的差值
            delta_x = event.locationInWindow().x - self.mouse_initial_pos.x
            delta_y = event.locationInWindow().y - self.mouse_initial_pos.y

            # 创建新的位置，手动计算 x 和 y 坐标
            new_origin_x = self.frame().origin.x + delta_x
            new_origin_y = self.frame().origin.y + delta_y

            # 设置新的 frame
            self.setFrameOrigin_(NSPoint(new_origin_x, new_origin_y))
            self.mouse_initial_pos = event.locationInWindow()


class BlurWindowApp:
    def __init__(self):
        # 初始化应用
        self.app = NSApplication.sharedApplication()
        self.app.setActivationPolicy_(NSApplicationActivationPolicyRegular)
        self.app.setActivationPolicy_(NSApplicationActivationPolicyAccessory)

        # 定义窗口样式
        # window_style = (1 << 0) | (1 << 1) | (1 << 3)  # 标题栏 + 可关闭 + 可调整大小
        window_style = 1 << 1

        # 创建窗口
        self.window = (
            DraggableWindow.alloc().initWithContentRect_styleMask_backing_defer_(
                NSRect((100, 100), (80, 30)),  # 窗口位置和大小
                window_style,  # 窗口样式
                2,  # 缓冲区存储
                False,  # 是否延迟创建窗口
            )
        )
        self.window.setTitle_("Blurred Window")
        self.window.makeKeyAndOrderFront_(None)
        # 添加毛玻璃效果
        # self.add_blur_effect()
        # self.set_rounded_corners(5)  # 设置圆角
        self.set_transparent_background()  # 设置透明背景
        self.window.setLevel_(3)  # 3是 `NSStatusWindowLevel`，它会让窗口始终显示在最前面

        # 激活应用
        self.app.activateIgnoringOtherApps_(True)

    def set_rounded_corners(self, radius):
        """为窗口设置圆角"""
        # 获取内容视图
        content_view = self.window.contentView()
        # 启用图层支持
        content_view.setWantsLayer_(True)

        # 获取视图的图层并设置圆角半径
        content_layer = content_view.layer()
        content_layer.setCornerRadius_(radius)
        content_layer.setMasksToBounds_(True)  # 让内容裁剪以实现圆角效果

    def set_transparent_background(self):
        """设置透明背景，避免圆角白边"""
        # 获取窗口的内容视图
        content_view = self.window.contentView()

        # 设置内容视图背景透明
        content_view.setBackgroundColor_(NSColor.clearColor())

        # 设置窗口背景透明
        self.window.setOpaque_(False)  # 禁止窗口不透明
        self.window.setBackgroundColor_(NSColor.clearColor())  # 设置窗口背景为透明

        # 获取并设置窗口内容视图的layer
        # content_layer = content_view.layer()
        # content_layer.setBackgroundColor_(NSColor.clearColor().CGColor())

    def add_blur_effect(self):
        # 创建毛玻璃视图
        blur_view = NSVisualEffectView.alloc().initWithFrame_(
            self.window.contentView().bounds()
        )
        blur_view.setAutoresizingMask_(NSViewWidthSizable | NSViewHeightSizable)
        blur_view.setBlendingMode_(NSVisualEffectBlendingModeBehindWindow)
        blur_view.setMaterial_(1)  # 毛玻璃材质
        blur_view.setState_(1)  # 激活状态
        # 添加毛玻璃视图到窗口
        self.window.contentView().addSubview_(blur_view)

    def add_number_label(self, number):
        # 创建文本框（只读，用于显示数字）
        font = NSFont.systemFontOfSize_(24)
        fontSmall = NSFont.systemFontOfSize_(18)
        font_manager = AppKit.NSFontManager.sharedFontManager()
        italic_font = font_manager.convertFont_toHaveTrait_(
            fontSmall, AppKit.NSFontItalicTrait
        )
        bold_italic_font = font_manager.convertFont_toHaveTrait_(
            italic_font, AppKit.NSFontBoldTrait
        )
        height = font.ascender() - font.descender() + font.leading()
        heightSmall = fontSmall.ascender() - fontSmall.descender() + fontSmall.leading()

        red = 252 / 255.0
        green = 83 / 255.0
        blue = 88 / 255.0
        alpha = 1.0
        custom_color = NSColor.colorWithCalibratedRed_green_blue_alpha_(
            red, green, blue, alpha
        )  # 淡蓝色

        fred = 135 / 255.0
        fgreen = 180 / 255.0
        fblue = 83 / 255.0
        falpha = 1.0
        f_custom_color = NSColor.colorWithCalibratedRed_green_blue_alpha_(
            fred, fgreen, fblue, falpha
        )  # 淡蓝色

        labelIcon = NSTextField.alloc().initWithFrame_(
            NSRect((0, (30 - height) / 2), (30, height))
        )
        labelIcon.setStringValue_(" 󰐰 ")
        labelIcon.setTextColor_(custom_color)
        labelIcon.setBezeled_(False)
        labelIcon.setDrawsBackground_(False)
        labelIcon.setEditable_(False)
        labelIcon.setSelectable_(False)
        labelIcon.setFont_(font)
        self.window.contentView().addSubview_(labelIcon)

        label = NSTextField.alloc().initWithFrame_(
            NSRect(
                (labelIcon.frame().size.width, (30 - heightSmall) / 2),
                (80, heightSmall),
            )
        )
        label.setStringValue_(number)  # 设置显示的数字
        label.setFont_(bold_italic_font)  # 设置字体大小
        label.setTextColor_(f_custom_color)
        # label.setAlignment_(1)  # 居中对齐
        label.setBezeled_(False)  # 无边框
        label.setDrawsBackground_(False)  # 无背景
        label.setEditable_(False)  # 只读
        label.setSelectable_(False)  # 不可选中

        # 将文本框添加到窗口内容视图
        self.window.contentView().addSubview_(label)

        return label

    def update_label(self, number):
        self.label.setStringValue_(str(number))


def start_async_loop(loop):
    """在新线程中启动 asyncio 循环"""
    asyncio.set_event_loop(loop)
    loop.run_forever()


if __name__ == "__main__":
    app = BlurWindowApp()
    glabel = app.add_number_label("")
    loop = asyncio.new_event_loop()
    threading.Thread(target=start_async_loop, args=(loop,), daemon=True).start()
    loop.call_soon_threadsafe(asyncio.create_task, run())
    runEventLoop()
