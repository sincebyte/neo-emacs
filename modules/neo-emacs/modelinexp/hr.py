def main():
    import asyncio
    from bleak import BleakClient, BleakError

    # 设备的蓝牙地址
    DEVICE_ADDRESS = "146407C2-EBE5-2A03-2AA5-338CA1AECCE5"
    HEART_RATE_MEASUREMENT_UUID = "2A37"

    # 处理接收到的心率通知
    def heart_rate_notification_handler(characteristic, data):
        # 假设数据格式是标准的心率测量格式，解析心率值
        if len(data) >= 2:
            heart_rate = data[1]  # 数据的第二个字节是心率值
            with open("/Users/van/.hr", "w") as f:
                f.write(f"{heart_rate}")
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


    # 运行异步任务
    asyncio.run(run())

if __name__ == "__main__":
    from multiprocessing import freeze_support
    freeze_support()
    main()

