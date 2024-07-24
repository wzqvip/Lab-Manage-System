import tkinter as tk
from tkinter import messagebox

import serial


def verify_fingerprint(port="/dev/ttyUSB0", baudrate=9600):
    pass

def scan_barcode():
    pass

def get_weight(port="/dev/ttyUSB1", baudrate=9600):
    ser = serial.Serial(port, baudrate, timeout=1)
    # 发送称重命令（根据秤的通信协议）
    ser.write(b"weight_command")
    weight = ser.readline().decode("utf-8").strip()
    ser.close()
    return weight

class LabManagementGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("实验室管理系统")

        self.verify_button = tk.Button(
            root, text="验证指纹", command=self.verify_fingerprint
        )
        self.verify_button.pack(pady=10)

        self.scan_button = tk.Button(root, text="扫描条码", command=self.scan_barcode)
        self.scan_button.pack(pady=10)

        self.weight_button = tk.Button(root, text="获取重量", command=self.get_weight)
        self.weight_button.pack(pady=10)

    def verify_fingerprint(self):
        result = verify_fingerprint()
        if result:
            messagebox.showinfo("验证结果", "指纹验证成功")
        else:
            messagebox.showerror("验证结果", "指纹验证失败")

    def scan_barcode(self):
        barcode = scan_barcode()
        if barcode:
            messagebox.showinfo("条码", f"扫描到的条码: {barcode}")
        else:
            messagebox.showerror("条码", "未能扫描到条码")

    def get_weight(self):
        weight = get_weight()
        messagebox.showinfo("重量", f"当前重量: {weight} 克")


if __name__ == "__main__":
    root = tk.Tk()
    app = LabManagementGUI(root)
    root.mainloop()
