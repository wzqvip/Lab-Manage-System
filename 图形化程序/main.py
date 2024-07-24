import sys
import serial
import serial.tools.list_ports
import time
import csv
from PyQt5.QtWidgets import (
    QApplication,
    QWidget,
    QPushButton,
    QVBoxLayout,
    QComboBox,
    QLabel,
    QLineEdit,
    QListWidget,
    QMessageBox,
    QTextEdit,
)


class MainWindow(QWidget):
    def __init__(self):
        super().__init__()

        self.initUI()
        self.ser = None

    def initUI(self):
        self.setWindowTitle("选择串口")
        self.setGeometry(100, 100, 400, 200)

        # 创建布局
        layout = QVBoxLayout()

        # 串口选择下拉菜单
        self.port_select = QComboBox(self)
        self.port_select.addItems(self.get_serial_ports())
        layout.addWidget(QLabel("选择串口号:"))
        layout.addWidget(self.port_select)

        # 连接按钮
        connect_button = QPushButton("连接", self)
        connect_button.clicked.connect(self.connect_serial)
        layout.addWidget(connect_button)

        self.setLayout(layout)

    def get_serial_ports(self):
        ports = serial.tools.list_ports.comports()
        return [port.device for port in ports]

    def connect_serial(self):
        selected_port = self.port_select.currentText()
        try:
            self.ser = serial.Serial(selected_port, 9600, timeout=1)
            time.sleep(2)  # 等待串口稳定
            self.fingerprint_manager = FingerprintManager(self.ser)
            self.fingerprint_manager.show()
            self.close()
        except serial.SerialException as e:
            QMessageBox.warning(self, "错误", f"无法连接到串口: {e}")


class FingerprintManager(QWidget):
    def __init__(self, ser):
        super().__init__()

        self.ser = ser
        self.users = {}  # 存储用户名和指纹ID的映射
        self.load_users()
        self.initUI()

    def initUI(self):
        self.setWindowTitle("指纹管理系统")
        self.setGeometry(100, 100, 600, 400)

        # 创建布局
        main_layout = QVBoxLayout()

        # 用户名输入
        self.name_input = QLineEdit(self)
        self.name_input.setPlaceholderText("输入用户名")
        main_layout.addWidget(self.name_input)

        # 注册按钮
        register_button = QPushButton("注册", self)
        register_button.clicked.connect(self.register_user)
        main_layout.addWidget(register_button)

        # 删除按钮
        delete_button = QPushButton("删除", self)
        delete_button.clicked.connect(self.delete_user)
        main_layout.addWidget(delete_button)

        # 用户列表
        self.user_list = QListWidget(self)
        main_layout.addWidget(self.user_list)

        # 登录按钮
        login_button = QPushButton("登录", self)
        login_button.clicked.connect(self.login_user)
        main_layout.addWidget(login_button)

        # 用户信息显示
        self.user_info_label = QLabel("未登录", self)
        main_layout.addWidget(self.user_info_label)

        # 串口调试信息显示
        self.debug_text = QTextEdit(self)
        self.debug_text.setReadOnly(True)
        main_layout.addWidget(QLabel("调试信息:"))
        main_layout.addWidget(self.debug_text)

        self.setLayout(main_layout)

        self.update_user_list()

    def update_debug_text(self, message):
        self.debug_text.append(message)

    def register_user(self):
        username = self.name_input.text()
        if not username:
            QMessageBox.warning(self, "错误", "请输入用户名")
            return

        if username in self.users:
            QMessageBox.warning(self, "错误", "用户名已存在")
            return

        # 为用户分配一个新的指纹ID
        new_id = len(self.users) + 1

        # 发送注册命令给Arduino
        self.ser.write(f"fp_enroll {new_id}\n".encode())
        self.update_debug_text(f"Sent: fp_enroll {new_id}")

        while True:
            time.sleep(1)
            response = self.ser.readline().decode("utf-8").strip()
            self.update_debug_text(f"Received: {response}")

            if response == "fp_enroll_press":
                QMessageBox.information(self, "提示", "请按下手指")
            elif response == "fp_enroll_remove":
                QMessageBox.information(self, "提示", "请移开手指")
            elif response == "fp_enroll_press_again":
                QMessageBox.information(self, "提示", "请再次按下手指")
            elif response == "fp_enroll_ok":
                self.users[username] = new_id
                self.save_users()
                self.update_user_list()
                QMessageBox.information(self, "成功", "指纹注册成功")
                break
            elif response.endswith("Image taken") or response.endswith("Image converted"):
                self.update_debug_text(f"Received: {response}")
            elif response in [
                "fp_enroll_fail",
                "Communication error",
                "Imaging error",
                "Unknown error",
                "Image too messy",
                "Could not find fingerprint features",
                "Error writing to flash",
                "Could not store in that location",
            ]:
                QMessageBox.warning(self, "错误", "指纹注册失败")
                self.update_debug_text(f"Error: {response}")
                break
            else:
                self.update_debug_text(f"Unknown response: {response}")

    def delete_user(self):
        selected_item = self.user_list.currentItem()
        if not selected_item:
            QMessageBox.warning(self, "错误", "请选择要删除的用户")
            return

        user_info = selected_item.text()
        username, fingerprint_id = user_info.split(": ")

        # 发送删除命令给Arduino
        self.ser.write(f"fp_delete {fingerprint_id}\n".encode())
        self.update_debug_text(f"Sent: fp_delete {fingerprint_id}")

        while True:
            if self.ser.in_waiting > 0:
                response = self.ser.readline().decode("utf-8").strip()
                self.update_debug_text(f"Received: {response}")
                if response == "fp_delete_ok":
                    del self.users[username]
                    self.save_users()
                    self.update_user_list()
                    QMessageBox.information(self, "成功", "用户删除成功")
                    break
                else:
                    QMessageBox.warning(self, "错误", "用户删除失败")
                    break

    def login_user(self):
        # 发送验证命令给Arduino
        self.ser.write("fp_detect\n".encode())
        self.update_debug_text("Sent: fp_detect")

        while True:
            if self.ser.in_waiting > 0:
                response = self.ser.readline().decode("utf-8").strip()
                self.update_debug_text(f"Received: {response}")
                if response.startswith("fp_detect_ok"):
                    fingerprint_id = response.split(" ")[1]
                    username = next((u for u, fid in self.users.items() if str(fid) == fingerprint_id), "未知用户")
                    self.user_info_label.setText(f"当前登录: {username} (ID: {fingerprint_id})")
                    break
                else:
                    self.user_info_label.setText("指纹验证失败")
                    QMessageBox.warning(self, "错误", "指纹验证失败")
                    break

    def load_users(self):
        try:
            with open("users.csv", mode="r", newline="") as file:
                reader = csv.reader(file)
                self.users = {rows[0]: int(rows[1]) for rows in reader}
        except FileNotFoundError:
            with open("users.csv", mode="w", newline="") as file:
                pass  # 创建文件

    def save_users(self):
        with open("users.csv", mode="w", newline="") as file:
            writer = csv.writer(file)
            for username, fingerprint_id in self.users.items():
                writer.writerow([username, fingerprint_id])

    def update_user_list(self):
        self.user_list.clear()
        for username, fingerprint_id in self.users.items():
            self.user_list.addItem(f"{username}: {fingerprint_id}")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    main_window = MainWindow()
    main_window.show()
    sys.exit(app.exec_())
