# Functional Requirements Trace

Tài liệu này đối chiếu trực tiếp từng yêu cầu trong `Multicast_Video_Streaming_Project_Requirement.docx` với vị trí triển khai tương ứng trong mã nguồn.

## 1. Server Requirements

### 1.1. Read a MJPEG video file frame by frame

Yêu cầu đã được triển khai trong `VideoStream.py`.

Vị trí chính:
- [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:27): `nextFrame()` đọc dữ liệu từ file theo từng khối và tìm biên frame JPEG.
- [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:43): tìm marker bắt đầu ảnh `SOI = 0xFFD8`.
- [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:56): tìm marker kết thúc ảnh `EOI = 0xFFD9`.
- [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:59): cắt đúng một frame JPEG hoàn chỉnh và trả về cho server.

Kết luận:
- File MJPEG được đọc đúng theo từng frame, không đọc kiểu cả file một lần.

### 1.2. Packetize each frame

Yêu cầu đã được triển khai trong `Server.py` và `Packet.py`.

Vị trí chính:
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:17): `MAX_PAYLOAD_SIZE = 1400` quy định kích thước payload tối đa cho mỗi packet.
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:57): bắt đầu quá trình chia frame thành nhiều fragment.
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:60): cắt từng đoạn payload nhỏ từ frame.
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:68): tạo `Packet()` cho từng fragment.
- [Packet.py](/home/chung/Desktop/ltm-project02/Packet.py:25): `encode()` đóng gói header + payload thành packet nhị phân.

Kết luận:
- Mỗi frame được packetize thành nhiều packet UDP nhỏ với custom header.

### 1.3. Send every frame to a multicast IP address

Yêu cầu đã được triển khai trong `Server.py`.

Vị trí chính:
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:15): multicast group là `239.1.1.1`.
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:16): multicast port là `5004`.
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:79): server gửi packet bằng `sendto()` tới địa chỉ multicast.

Kết luận:
- Tất cả packet của frame đều được gửi tới đúng multicast IP/port theo đề bài.

### 1.4. Broadcast frames at approximately 20 FPS (50 ms/frame)

Yêu cầu đã được triển khai trong `Server.py`.

Vị trí chính:
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:82): ghi chú về việc duy trì tốc độ phát.
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:83): `time.sleep(0.05)` tương đương 50 ms mỗi frame.

Kết luận:
- Server phát frame ở tốc độ xấp xỉ `20 FPS` như yêu cầu.

### 1.5. Continue streaming until the video ends

Yêu cầu đã được triển khai trong `Server.py`.

Vị trí chính:
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:45): vòng lặp `while True` giúp server tiếp tục phát liên tục.
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:48): mỗi vòng lặp lấy frame tiếp theo từ `VideoStream`.

Kết luận:
- Server không dừng sau vài frame, mà tiếp tục stream cho đến khi video đi hết nội dung.

### 1.6. Restart the video automatically after reaching the last frame

Yêu cầu đã được triển khai trong `VideoStream.py`.

Vị trí chính:
- [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:35): nếu đọc hết file và buffer rỗng, hệ thống mở lại file từ đầu.
- [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:36): gọi `open_file()` để reset con trỏ file.
- [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:66): nếu chạm EOF khi frame chưa hoàn tất, tiếp tục mở lại file để loop.

Kết luận:
- Video tự động phát lại từ đầu mà không cần restart server thủ công.

## 2. Client Requirements

### 2.1. Join the multicast group

Yêu cầu đã được triển khai trong `Client.py`.

Vị trí chính:
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:54): client bind vào `0.0.0.0:5004`.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:62): tạo `mreq` và join group bằng `IP_ADD_MEMBERSHIP`.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:64): in log xác nhận join thành công.

Kết luận:
- Client thực sự tham gia multicast group trước khi nhận dữ liệu.

### 2.2. Receive multicast packets

Yêu cầu đã được triển khai trong `Client.py`.

Vị trí chính:
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:81): `receive_packets()` là luồng nhận dữ liệu chính.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:89): `recvfrom(2048)` nhận packet UDP từ multicast socket.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:175): luồng hiển thị lấy frame đã ghép từ queue, tách khỏi luồng nhận.

Kết luận:
- Client có cơ chế nhận multicast packet liên tục bằng receiver thread riêng.

### 2.3. Decode received packets

Yêu cầu đã được triển khai trong `Packet.py` và `Client.py`.

Vị trí chính:
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:95): tạo đối tượng `Packet()` để giải mã dữ liệu nhận được.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:96): gọi `packet.decode(data)`.
- [Packet.py](/home/chung/Desktop/ltm-project02/Packet.py:45): `decode()` tách header và payload từ byte stream.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:150): sau khi đủ fragment, client ghép lại thành ảnh JPEG hoàn chỉnh.

Kết luận:
- Packet nhận được đã được decode đúng theo custom packet format trước khi sử dụng.

### 2.4. Display the video in real time

Yêu cầu đã được triển khai trong `Client.py`.

Vị trí chính:
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:183): chuyển bytes sang `numpy` buffer.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:184): giải mã JPEG bằng `cv2.imdecode`.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:212): hiển thị frame bằng `cv2.imshow`.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:207): hiển thị `Render FPS` trên khung hình.

Kết luận:
- Video được hiển thị theo thời gian thực bằng OpenCV.

### 2.5. Leave the multicast group when exiting

Yêu cầu đã được triển khai trong `Client.py`.

Vị trí chính:
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:231): `cleanup()` chịu trách nhiệm dọn tài nguyên khi thoát.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:239): tạo lại `mreq` để rời multicast group.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:240): gọi `IP_DROP_MEMBERSHIP`.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:241): đóng socket.

Kết luận:
- Client rời multicast group và giải phóng tài nguyên đúng yêu cầu.

## 3. Running Requirements

### 3.1. Server: `python Server.py <file MJPEG>`

Yêu cầu đã được hỗ trợ trong `Server.py`.

Vị trí chính:
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:20): kiểm tra tham số dòng lệnh.
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:21): in cú pháp `python Server.py <file MJPEG>` nếu thiếu tham số.
- [Server.py](/home/chung/Desktop/ltm-project02/Server.py:24): lấy tên file MJPEG từ `sys.argv[1]`.

Ví dụ chạy:

```bash
python Server.py movie.Mjpeg
```

### 3.2. Client: `python Client.py`

Yêu cầu đã được hỗ trợ trong `Client.py`.

Vị trí chính:
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:249): entry point của chương trình client.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:258): tạo `MulticastClient(...)`.
- [Client.py](/home/chung/Desktop/ltm-project02/Client.py:259): chạy client bằng `client.run()`.

Ví dụ chạy:

```bash
python Client.py
```

## 4. Tổng kết

Tất cả các mục trong phần `Functional Requirements` và `Running` của tài liệu yêu cầu đều đã có vị trí triển khai rõ ràng trong mã nguồn.

Nếu cần kiểm tra nhanh theo file:
- Server side: [Server.py](/home/chung/Desktop/ltm-project02/Server.py:1), [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:1), [Packet.py](/home/chung/Desktop/ltm-project02/Packet.py:1)
- Client side: [Client.py](/home/chung/Desktop/ltm-project02/Client.py:1), [Packet.py](/home/chung/Desktop/ltm-project02/Packet.py:1)
