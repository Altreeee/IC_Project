import paho.mqtt.client as mqtt  

# 配置远程服务器信息  
broker_address = "47.242.58.59"  # 替换为你的服务器 IP 地址  
port = 1883  # MQTT 默认端口  
topic = "test/topic"  # 主题名称  
message = "Hello, MQTT!"  # 要发送的消息  

# 用户名和密码（替换为你的实际用户名和密码）  
username = "username"  # 替换为你的用户名  
password = "11161678"  # 替换为你的密码  

# 创建 MQTT 客户端  
client = mqtt.Client()  

# 设置用户名和密码  
client.username_pw_set(username, password)  

try:  
    # 连接到远程服务器  
    client.connect(broker_address, port, 60)  

    # 发布消息到指定主题  
    client.publish(topic, message)  
    print(f"消息已发送到主题 '{topic}': {message}")  

    # 断开连接  
    client.disconnect()  
except Exception as e:  
    print(f"无法连接到服务器或发送消息: {e}")