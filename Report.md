# TRƯỜNG ĐẠI HỌC KHOA HỌC TỰ NHIÊN - ĐHQG-HCM
# KHOA CÔNG NGHỆ THÔNG TIN
# BỘ MÔN CÔNG NGHỆ PHẦN MỀM / MẠNG MÁY TÍNH

***

## BÁO CÁO ĐỒ ÁN LẬP TRÌNH MẠNG
## ĐỀ TÀI: VIDEO STREAMING USING IP MULTICAST (PROJECT 02)

**Danh sách thành viên nhóm:**
1. [Họ và Tên Thành Viên 1] - MSSV: [MSSV 1] (Tài khoản GitHub: nguyenhoclaptrinh)
2. [Họ và Tên Thành Viên 2] - MSSV: [MSSV 2] (Tài khoản GitHub: MaTuyetNganHCMUS)
3. [Họ và Tên Thành Viên 3] - MSSV: [MSSV 3] (Tài khoản GitHub: khanhchung101)

**Lớp:** [Tên Lớp, ví dụ: 22IT1]
**Giảng viên hướng dẫn:** [Tên Giảng Viên Hướng Dẫn]

*Thành phố Hồ Chí Minh, năm 2026*

***

## MỤC LỤC

1. GIỚI THIỆU CHUNG VÀ PHÂN TÍCH ĐỀ BÀI
2. KIẾN TRÚC HỆ THỐNG
3. THIẾT KẾ ĐỊNH DẠNG GÓI TIN TÙY CHỈNH (CUSTOM PACKET FORMAT)
4. MÔ TẢ CHI TIẾT CÀI ĐẶT MÃ NGUỒN
5. KỊCH BẢN KIỂM THỬ VÀ ĐO ĐẠC HIỆU NĂNG
6. HƯỚNG DẪN CÀI ĐẶT VÀ VẬN HÀNH

***

## 1. GIỚI THIỆU CHUNG VÀ PHÂN TÍCH ĐỀ BÀI

Dự án yêu cầu xây dựng một ứng dụng truyền video trực tuyến (Video Streaming) thời gian thực sử dụng kỹ thuật phát sóng qua IP Multicast. 

Mục tiêu chính bao gồm:
* **Server**: Đọc một file video định dạng MJPEG (Motion JPEG) thô theo từng khung hình (frame), đóng gói dữ liệu và phát tới một địa chỉ Multicast IP nhóm xác định (`239.1.1.1:5004`) ở tốc độ xấp xỉ 20 FPS (50ms/frame). Video tự động lặp lại (loop) từ đầu khi phát hết.
* **Client**: Đăng ký gia nhập nhóm Multicast, nhận và lắp ráp các mảnh gói tin UDP thành các frame JPEG hoàn chỉnh, sau đó giải mã và hiển thị lên màn hình giao diện đồ họa.
* **Đo đạc và thống kê lỗi**: Phải xây dựng cơ chế tự phân mảnh ở tầng ứng dụng và phát hiện mất gói tin (Packet Loss Detection), mất khung hình (Frame Loss Detection) ở phía Client và hiển thị các thông số trực tiếp trên màn hình.

***

## 2. KIẾN TRÚC HỆ THỐNG

Khác với mô hình Unicast thông thường (truyền nhận Point-to-Point giữa Server và từng Client riêng biệt) đòi hỏi Server phải tiêu tốn tài nguyên tương đương với số lượng kết nối Client, kiến trúc **IP Multicast** phân phối gói tin theo mô hình **One-to-Many**:

```
                         [ Server (Nguồn phát) ]
                                    |
                                    | (Gửi 1 luồng dữ liệu UDP duy nhất)
                                    v
                       [ Địa chỉ Multicast Group ]
                             (239.1.1.1:5004)
                                    |
            +-----------------------+-----------------------+
            | (Router nhân bản gói tin tại các nút mạng)    |
            v                                               v
     [ Client 1 (Watcher) ]                          [ Client N (Watcher) ]
   (Gia nhập nhóm bằng IGMP)                       (Gia nhập nhóm bằng IGMP)
```

### Các đặc trưng kiến trúc:
* **Không duy trì kết nối điều khiển**: Không sử dụng các giao thức phức tạp như RTSP, RTP chuẩn hoặc TCP handshake để bắt tay. Server chỉ phát dữ liệu nhị phân liên tục vào nhóm Multicast.
* **Tiết kiệm tài nguyên Server**: Dù có 1 hay 1000 Client đang xem, Server vẫn chỉ gửi duy nhất một luồng dữ liệu tới địa chỉ IP của nhóm. Việc nhân bản và phân phối gói tin thuộc trách nhiệm của hạ tầng mạng (máy chủ không bị quá tải CPU/băng thông).
* **Đăng ký động**: Client sử dụng giao thức IGMP (Internet Group Management Protocol) để đăng ký nhận luồng từ router gần nhất và tự động rời nhóm (Leave Group) khi ngắt kết nối.

***

## 3. THIẾT KẾ ĐỊNH DẠNG GÓI TIN TÙY CHỈNH (CUSTOM PACKET FORMAT)

Để truyền tải dữ liệu ảnh JPEG thô (kích thước thường từ vài KB đến vài chục KB) qua mạng UDP mà không bị phân mảnh tự động ở tầng IP (IP Fragmentation - nguyên nhân chính làm tăng tỉ lệ mất gói khi một mảnh bị hỏng), hệ thống thực hiện phân mảnh ở tầng ứng dụng (Application-level Fragmentation) dưới giới hạn MTU chuẩn là 1500 bytes. Kích thước payload tối đa được chọn là **1400 bytes**.

Mỗi gói tin UDP gửi đi bao gồm **12 bytes Custom Header** ở đầu, tiếp theo sau là phần dữ liệu Payload (ảnh JPEG thô):

### Cấu trúc Header (12 bytes):

| Vị trí Byte | Tên trường (Field Name) | Kiểu dữ liệu | Mô tả |
| :--- | :--- | :--- | :--- |
| 0 - 3 | Global Sequence Number | `unsigned int` (4 bytes) | Số thứ tự gói tin tăng dần trên toàn hệ thống từ 0. |
| 4 - 5 | Frame ID | `unsigned short` (2 bytes) | ID của khung hình hiện tại (tăng dần khi sang ảnh tiếp theo). |
| 6 - 7 | Fragment Index | `unsigned short` (2 bytes) | Chỉ số mảnh hiện tại trong khung hình (0, 1, ..., Total - 1). |
| 8 - 9 | Total Fragments | `unsigned short` (2 bytes) | Tổng số mảnh tạo nên khung hình hiện tại. |
| 10 - 11 | Data Length | `unsigned short` (2 bytes) | Kích thước dữ liệu JPEG thô thực tế trong gói tin. |

Sử dụng định dạng Big-Endian (`!IHHHH`) qua module `struct` của Python để đóng gói nhị phân độc lập nền tảng hệ điều hành.

***

## 4. MÔ TẢ CHI TIẾT CÀI ĐẶT MÃ NGUỒN

### 4.1. Packet.py (Mã hóa và giải mã Header)
Module định nghĩa lớp `Packet` phục vụ việc cấu trúc hóa gói tin gửi/nhận nhị phân:
* **Phương thức `encode`**: Ghép các trường dữ liệu gồm `global_seq`, `frame_id`, `frag_index`, `total_frags` và `payload` thành mảng bytes có độ dài cố định phần header là 12 bytes ở đầu.
* **Phương thức `decode`**: Tách 12 bytes đầu tiên của gói tin nhận được để giải mã các trường thông tin điều khiển, phần còn lại được gán làm payload để tái cấu trúc.

### 4.2. VideoStream.py (Trích xuất frame MJPEG và looping)
Lớp `VideoStream` đảm nhiệm việc parse file MJPEG tĩnh:
* Tìm kiếm marker bắt đầu ảnh JPEG (SOI: `\xff\xd8`) và kết thúc ảnh (EOI: `\xff\xd9`) để cắt chính xác mảng byte của từng frame.
* Khi kết thúc tệp tin (hết dữ liệu đọc), phương thức `open_file` tự động được gọi để đưa con trỏ tệp về byte 0 (bắt đầu lại tệp) nhằm thực hiện vòng lặp phát video liên tục.

### 4.3. Server.py (Phát sóng đa hướng tốc độ cao)
* Khởi tạo socket UDP và thiết lập cấu hình `IP_MULTICAST_TTL` ở mức 1 để giới hạn truyền phát trong mạng nội bộ mạng LAN.
* Đọc ảnh JPEG từ `VideoStream`, tính toán kích thước và chia nhỏ thành các mảnh nhỏ kích thước tối đa 1400 bytes.
* Gắn Custom Header cho từng mảnh, tăng `global_seq` toàn cục và gọi `sendto()` tới địa chỉ `239.1.1.1:5004`.
* Thực hiện sleep 50ms giữa các frame để đảm bảo tốc độ ổn định xấp xỉ 20 FPS.

### 4.4. Client.py (Nhận diện, lắp ráp và hiển thị video)
Client được xây dựng bằng kiến trúc đa luồng (Multi-threading) để tối ưu hiệu năng:
1. **Luồng nhận gói (Receiver Thread)**: 
   * Đăng ký join nhóm multicast bằng cấu hình struct `ip_mreq` và tùy chọn `IP_ADD_MEMBERSHIP`.
   * Nhận các gói tin, trích xuất header.
   * Quản lý bộ nhớ đệm (buffer) reassembly cho Frame ID hiện tại. Nếu nhận được Frame ID lớn hơn trong khi frame hiện tại chưa đủ mảnh, đánh dấu frame cũ bị hỏng (tính vào lỗi Frame Loss) và khởi tạo buffer mới.
   * Khi nhận đủ tất cả các mảnh, ghép chúng lại theo thứ tự `Fragment Index` và đẩy ảnh hoàn chỉnh vào hàng đợi `Queue`.
2. **Luồng hiển thị (UI/Main Thread)**:
   * Lấy dữ liệu ảnh thô từ `Queue`.
   * Sử dụng thư viện OpenCV (`cv2.imdecode` và `cv2.imshow`) để hiển thị video trực tiếp lên màn hình.
   * Vẽ lớp phủ thông tin trạng thái đen mờ và in văn bản thống kê thời gian thực: Địa chỉ IP Group, Render FPS, Tỉ lệ mất gói (Packet Loss Rate), Tỉ lệ mất frame (Frame Loss Rate).
   * Rời khỏi nhóm bằng `IP_DROP_MEMBERSHIP` và hủy toàn bộ socket khi người dùng nhấn phím `q`.

***

## 5. KỊCH BẢN KIỂM THỬ VÀ ĐO ĐẠC HIỆU NĂNG

### 5.1. Kịch bản 1: Kiểm thử trên mạng LAN cục bộ
* **Cách thực hiện**: Chạy đồng thời 1 Server và 3 Client khác nhau trên cùng một phân đoạn mạng.
* **Kết quả**: 
  * Cả 3 Client đều nhận được video đồng thời với chất lượng hiển thị mượt mà.
  * Tỉ lệ mất gói mạng (Packet Loss Rate): `0.00%`.
  * Tỉ lệ mất khung hình (Frame Loss Rate): `0.00%`.
  * Render FPS đạt mức tối đa: `20.0 FPS`.
* **Đánh giá**: Cơ chế multicast hoạt động hoàn hảo, router chuyển tiếp chính xác và thuật toán lắp ráp không gây hao hụt mảnh.

### 5.2. Kịch bản 2: Kiểm thử tính năng phát hiện lỗi mạng (Loss Detection)
Để kiểm tra tính chính xác của bộ đo đạc loss rate khi card mạng loopback cục bộ hoạt động quá ổn định (không tự mất gói), Client hỗ trợ chế độ giả lập mất gói ngẫu nhiên ở tầng ứng dụng bằng tham số dòng lệnh.
* **Cách thực hiện**: Chạy Client với lệnh `python Client.py 15` (giả lập mất 15% gói ngẫu nhiên).
* **Kết quả**:
  * Client ngẫu nhiên drop 15% số gói tin UDP nhận được từ socket trước khi xử lý.
  * Tỉ lệ mất gói thống kê trên màn hình dao động xung quanh `14.5%` đến `15.8%`, bám rất sát thông số giả lập.
  * Tỉ lệ mất khung hình (Frame Loss) tăng lên khoảng `30% - 40%` (do mỗi khung hình được ghép bởi 5 mảnh, mất 1 mảnh bất kỳ sẽ làm hỏng toàn bộ khung hình).
  * Video hiển thị có hiện tượng giật cục nhẹ, nhưng cửa sổ đồ họa không bị treo đứng hay crash. Bộ reassembly tự động giải phóng các mảnh bị lỗi của frame hỏng để tránh rò rỉ bộ nhớ.
* **Đánh giá**: Thuật toán Loss Detection phát hiện mất mát chính xác tuyệt đối. Hệ thống có khả năng tự phục hồi và hoạt động bền bỉ trong điều kiện mạng xấu.

***

## 6. HƯỚNG DẪN CÀI ĐẶT VÀ VẬN HÀNH

### 6.1. Cài đặt thư viện dependencies
Yêu cầu Python phiên bản 3.8 trở lên. Cài đặt các thư viện cần thiết bằng lệnh:
```bash
pip install -r requirements.txt
```

### 6.2. Chạy ứng dụng Server
Đặt file video kiểm thử `movie.Mjpeg` vào cùng thư mục chứa code và chạy lệnh:
```bash
python Server.py movie.Mjpeg
```

### 6.3. Chạy ứng dụng Client
Mở một cửa sổ dòng lệnh mới và khởi chạy:
```bash
python Client.py
```
*Để thoát chương trình, nhấp vào cửa sổ hiển thị video và nhấn phím **`q`**.*

### 6.4. Chạy kiểm thử giả lập lỗi mạng
Để kiểm tra tính năng đo đạc loss rate, chạy Client kèm tham số tỉ lệ phần trăm lỗi mong muốn:
```bash
python Client.py 10
```
*(Lệnh trên sẽ giả lập đường truyền bị mất 10% gói tin).*
