# BÁO CÁO ĐỒ ÁN LẬP TRÌNH MẠNG
## ĐỀ TÀI: VIDEO STREAMING USING IP MULTICAST (PROJECT 02)

**Môn học:** Lập trình mạng  
**Đề bài:** Multicast Video Streaming  
**Repository:** `ltm-project02`  
**Nhóm thực hiện:** Cập nhật theo danh sách nộp bài chính thức của nhóm  
**Thời gian:** 2026

---

## 1. Mục tiêu đề tài

Mục tiêu của đồ án là xây dựng một hệ thống truyền video thời gian thực sử dụng **IP Multicast**. Server đọc file video MJPEG, chia mỗi frame thành các gói UDP có header tùy chỉnh, rồi phát liên tục tới multicast group `239.1.1.1:5004`. Nhiều client có thể cùng tham gia nhóm để xem chung một luồng video mà không yêu cầu server phải tạo kết nối riêng cho từng người xem.

Theo tài liệu `Multicast_Video_Streaming_Project_Requirement.docx`, hệ thống cần đáp ứng các yêu cầu sau:
- Server đọc file MJPEG theo từng frame.
- Server tự đóng gói frame và gửi tới multicast group.
- Server phát ở tốc độ xấp xỉ `20 FPS`.
- Video tự phát lại khi đi đến cuối file.
- Client join multicast group, nhận gói, giải mã, hiển thị video theo thời gian thực.
- Client rời multicast group khi thoát.
- Hệ thống có **custom packet format** và có cơ chế **loss detection**.

---

## 2. Kiến trúc hệ thống

Hệ thống sử dụng mô hình **one-to-many** của IP Multicast:

```text
                 +-------------------+
                 |  Server (Sender)  |
                 +-------------------+
                           |
                           | UDP multicast stream
                           v
                Multicast Group 239.1.1.1:5004
                   /             |             \
                  /              |              \
                 v               v               v
        +---------------+ +---------------+ +---------------+
        |   Client 1    | |   Client 2    | |   Client N    |
        +---------------+ +---------------+ +---------------+
```

### 2.1. Lý do chọn IP Multicast

So với unicast, multicast phù hợp hơn cho bài toán phát cùng một luồng dữ liệu đến nhiều người xem.

Ưu điểm chính:
- Server chỉ gửi **một** luồng UDP duy nhất tới địa chỉ nhóm multicast.
- Nhiều client có thể xem đồng thời mà không làm server phải nhân đôi kết nối.
- Router/switch hỗ trợ multicast sẽ chịu trách nhiệm phân phối gói tới các host đã join group.
- Kiến trúc này đúng với tinh thần đề bài: không cần RTSP, không cần RTP chuẩn, không cần control channel riêng.

### 2.2. Luồng hoạt động

1. Server mở file `movie.Mjpeg` và đọc từng frame JPEG.
2. Mỗi frame được chia thành nhiều fragment nhỏ.
3. Mỗi fragment được gắn custom header 12 byte.
4. Server gửi các fragment lần lượt tới `239.1.1.1:5004` qua UDP.
5. Client bind vào port `5004`, join multicast group bằng `IP_ADD_MEMBERSHIP`.
6. Client nhận packet, giải mã header, ghép các fragment thành frame hoàn chỉnh.
7. Client giải mã JPEG bằng OpenCV và hiển thị lên cửa sổ video.
8. Khi thoát, client gọi `IP_DROP_MEMBERSHIP` để rời nhóm multicast.

---

## 3. Thiết kế định dạng gói tin tùy chỉnh

Đề bài yêu cầu sử dụng **custom packet** thay vì giao thức RTP/RTSP chuẩn. Vì frame JPEG có thể lớn hơn kích thước phù hợp cho một gói UDP, hệ thống thực hiện **application-level fragmentation**.

### 3.1. Kích thước payload

- Kích thước payload tối đa cho mỗi packet: `1400 bytes`
- Mục tiêu: tránh fragmentation ở tầng IP khi MTU Ethernet phổ biến là `1500 bytes`

### 3.2. Header 12 bytes

Mỗi packet có cấu trúc:

| Byte | Trường | Kiểu | Ý nghĩa |
| :--- | :--- | :--- | :--- |
| 0-3 | Global Sequence Number | `unsigned int` | Số thứ tự gói tăng dần toàn cục |
| 4-5 | Frame ID | `unsigned short` | ID frame hiện tại |
| 6-7 | Fragment Index | `unsigned short` | Thứ tự mảnh trong frame |
| 8-9 | Total Fragments | `unsigned short` | Tổng số mảnh của frame |
| 10-11 | Data Length | `unsigned short` | Độ dài payload thực tế |

Định dạng nhị phân dùng trong code là:

```python
'!IHHHH'
```

Trong đó:
- `!` là Big-Endian / network byte order
- `I` là `unsigned int` 4 byte
- `H` là `unsigned short` 2 byte

### 3.3. Ý nghĩa của từng trường

- `Global Sequence Number`: dùng để phát hiện packet loss trên toàn luồng.
- `Frame ID`: dùng để biết fragment nào thuộc cùng một frame.
- `Fragment Index`: dùng để ghép các fragment đúng thứ tự.
- `Total Fragments`: dùng để biết khi nào đã nhận đủ frame.
- `Data Length`: dùng để kiểm tra độ dài payload hữu ích của packet.

### 3.4. Xử lý giới hạn 2 byte của Frame ID

Do `Frame ID` chỉ có 2 byte, giá trị truyền trên mạng chỉ nằm trong khoảng `0..65535`. Nếu stream chạy đủ lâu, giá trị này sẽ quay vòng.

Để hệ thống không lỗi khi phát lâu:
- Server gửi `frame_id % 65536`.
- Client mở rộng lại `Frame ID` thô thành bộ đếm tăng dần nội bộ bằng cơ chế unwrap.

Nhờ đó, hệ thống vẫn đúng với packet format của đề bài nhưng không bị hỏng sau khoảng 54.6 phút ở tốc độ 20 FPS.

---

## 4. Mô tả cài đặt mã nguồn

Repository gồm các file chính sau:

- `Server.py`: phát multicast video
- `Client.py`: nhận, ghép, hiển thị và thống kê loss
- `Packet.py`: encode/decode custom packet
- `VideoStream.py`: đọc file MJPEG theo từng frame
- `test_multicast.py`: receiver tối giản để kiểm tra đường truyền multicast
- `movie.Mjpeg`: dữ liệu video mẫu

### 4.1. `VideoStream.py`

Chức năng chính:
- Mở file MJPEG ở dạng nhị phân.
- Tìm marker bắt đầu ảnh JPEG `SOI = 0xFFD8`.
- Tìm marker kết thúc ảnh JPEG `EOI = 0xFFD9`.
- Trả về đúng dữ liệu thô của một frame.
- Khi đọc đến cuối file, tự động mở lại file từ đầu để loop video.

Điểm quan trọng:
- Hệ thống không phụ thuộc vào thư viện video container như FFmpeg.
- Việc đọc frame bám sát yêu cầu “Read a MJPEG video file frame by frame”.

### 4.2. `Packet.py`

Lớp `Packet` đóng vai trò chuẩn hóa packet trên cả bên gửi và bên nhận.

Các thao tác chính:
- `encode(...)`: nhận metadata và payload, ghép header 12 byte với dữ liệu ảnh.
- `decode(byte_stream)`: tách header và payload từ packet nhận được.

Lợi ích của module riêng:
- Dễ kiểm tra đúng/sai packet format.
- Tách biệt logic đóng gói khỏi logic mạng.
- Giúp client và server dùng chung một chuẩn dữ liệu.

### 4.3. `Server.py`

Server thực hiện các bước:

1. Nhận tham số dòng lệnh `python Server.py <file MJPEG>`.
2. Khởi tạo UDP socket với `IPPROTO_UDP`.
3. Cấu hình `IP_MULTICAST_TTL = 1` để giới hạn trong mạng cục bộ.
4. Đọc frame từ `VideoStream`.
5. Chia frame thành các fragment có payload tối đa `1400 bytes`.
6. Tạo packet bằng custom header.
7. Gửi từng packet tới `239.1.1.1:5004`.
8. `sleep(0.05)` để giữ tốc độ khoảng `20 FPS`.
9. Khi video hết, tiếp tục loop và phát lại từ đầu.

Đặc điểm đáng chú ý:
- Không có control channel riêng.
- Không có RTSP hay RTP.
- Phù hợp đúng mô tả trong tài liệu yêu cầu.

### 4.4. `Client.py`

Client được thiết kế theo mô hình đa luồng để tránh block giao diện.

#### a. Receiver thread

Luồng nhận có nhiệm vụ:
- Tạo socket UDP và bind `0.0.0.0:5004`.
- Join multicast group bằng `IP_ADD_MEMBERSHIP`.
- Nhận packet từ mạng.
- Decode header bằng `Packet.decode()`.
- Phát hiện packet loss dựa trên `Global Sequence Number`.
- Ghép fragment thành frame dựa trên `Frame ID`, `Fragment Index`, `Total Fragments`.
- Phát hiện frame loss nếu chuyển sang frame mới trong khi frame cũ chưa đủ mảnh.
- Đưa frame hoàn chỉnh vào `Queue` để luồng hiển thị sử dụng.

#### b. Main/UI thread

Luồng chính chịu trách nhiệm:
- Lấy frame bytes từ queue.
- Dùng `cv2.imdecode` để chuyển JPEG bytes thành ảnh.
- Hiển thị video bằng `cv2.imshow`.
- Overlay các chỉ số:
  - địa chỉ multicast group
  - render FPS
  - packet loss rate
  - frame loss rate
- Theo dõi phím `q` để thoát.
- Rời multicast group bằng `IP_DROP_MEMBERSHIP` khi kết thúc.

### 4.5. Cơ chế đo đạc lỗi

#### Packet loss detection

Client lưu `max_global_seq` lớn nhất đã thấy.

Khi nhận packet mới:
- Nếu `seq > max_global_seq + 1`, các giá trị ở giữa được tính là packet bị mất.
- `packet_loss_rate = packets_lost / packets_expected * 100`

#### Frame loss detection

Client theo dõi frame hiện tại đang ghép.

Nếu đã bắt đầu nhận frame `N`, nhưng xuất hiện packet của frame `N+1` trong khi frame `N` chưa đủ fragment:
- frame `N` được đánh dấu mất
- tăng bộ đếm `total_lost_frames`

Cách làm này phù hợp với đề bài vì nó phản ánh đúng hậu quả thực tế của packet loss ở tầng hiển thị: mất 1 fragment có thể làm hỏng cả frame.

---

## 5. Kiểm thử và đánh giá

### 5.1. Mục tiêu kiểm thử

Phần kiểm thử không chỉ nhằm chứng minh chương trình chạy được, mà còn phải chỉ ra rõ mỗi bài test đang xác nhận phần nào của hệ thống.

Các mục tiêu kiểm thử chính:
- Kiểm tra **cú pháp và khả năng import/chạy** của các file nguồn chính.
- Kiểm tra **server path**: đọc MJPEG, fragment frame, gửi multicast packet.
- Kiểm tra **custom packet format**: packet tạo ra ở server có decode lại được ở receiver/client.
- Kiểm tra **receiver path**: join multicast group, nhận packet, xử lý header, theo dõi sequence.
- Kiểm tra **display path**: client giải mã JPEG và hiển thị video real-time.
- Kiểm tra **loss detection path**: packet loss và frame loss statistics hoạt động.
- Kiểm tra **looping path**: video tự động quay lại từ đầu khi hết file.
- Kiểm tra **multi-client behavior**: nhiều client cùng nhận một stream multicast.

### 5.2. Kiểm thử cú pháp và khả năng chạy

**Đang test gì:**
- Tính hợp lệ cú pháp của các file Python chính.
- Khả năng import các module và chạy entry point mà không lỗi syntax.

**Test phần nào:**
- `Server.py`
- `Client.py`
- `Packet.py`
- `VideoStream.py`
- `test_multicast.py`

**Thực hiện ở đâu:**
- Chạy tại thư mục gốc repository.

**Lệnh kiểm thử:**

```bash
python3 -m py_compile Server.py Client.py Packet.py VideoStream.py test_multicast.py
```

**Kết quả:**
- Tất cả file pass `py_compile`.
- Không phát hiện lỗi cú pháp trong các thành phần chính.

**Ý nghĩa:**
- Xác nhận mã nguồn ở trạng thái có thể thực thi, là điều kiện nền để các bài test chức năng phía sau có giá trị.

### 5.3. Kiểm thử server-to-receiver end-to-end

**Đang test gì:**
- Server có thực sự phát multicast hay không.
- Packet được tạo ở server có được receiver nhận và decode đúng hay không.
- Sequence, frame ID, fragment index và payload size có đi xuyên suốt qua mạng đúng hay không.

**Test phần nào:**
- Phía gửi: `Server.py`
- Fragmentation và packet format: `Server.py` + `Packet.py`
- Phía nhận kỹ thuật: `test_multicast.py` + `Packet.py`

**Thực hiện ở đâu:**
- Chạy cục bộ trong cùng môi trường làm việc bằng hai tiến trình riêng.

**Lệnh kiểm thử:**

```bash
python3 Server.py movie.Mjpeg
python3 test_multicast.py
```

**Cách đọc kết quả:**
- `test_multicast.py` in ra `GlobalSeq`, `FrameID`, số fragment và kích thước payload của từng packet nhận được.
- Nếu receiver nhận packet liên tiếp và decode được các trường header, luồng multicast và custom packet đang hoạt động đúng.

**Kết quả quan sát ổn định:**
- Receiver join thành công multicast group `239.1.1.1:5004`.
- Receiver nhận được `30/30` packet trong lần kiểm thử ổn định.
- Các packet có đủ trường `GlobalSeq`, `FrameID`, `FragmentIndex`, `TotalFragments`, `Payload`.
- Tỉ lệ mất gói trong kịch bản cục bộ ổn định là `0.00%`.

**Ý nghĩa:**
- Chứng minh luồng `Server -> Multicast -> Receiver` hoạt động thực tế.
- Chứng minh custom packet format có thể encode ở server và decode ở receiver.
- Chứng minh phần fragment/payload đang chạy đúng theo thiết kế.

### 5.4. Kiểm thử client receive/reassembly/display path

**Đang test gì:**
- Client có join multicast group, nhận packet, ghép lại frame JPEG và hiển thị video được không.

**Test phần nào:**
- `Client.py`
- `Packet.py`
- `VideoStream.py` gián tiếp thông qua dữ liệu do server phát

**Thực hiện ở đâu:**
- Trong môi trường desktop có hỗ trợ OpenCV window.

**Lệnh kiểm thử:**

```bash
python3 Server.py movie.Mjpeg
python3 Client.py
```

**Những điểm cần quan sát trên cửa sổ client:**
- Cửa sổ video mở thành công.
- Video hiển thị liên tục, không bị treo.
- Overlay hiển thị `Group`, `Render FPS`, `Packet Loss`, `Frame Loss`.
- Nhấn `q` thì client thoát và dọn tài nguyên.

**Ý nghĩa:**
- Đây là bài test trực tiếp cho yêu cầu “Receive multicast packets”, “Decode received packets”, “Display the video in real time”, và “Leave the multicast group when exiting”.

### 5.5. Kiểm thử nhiều client đồng thời

**Đang test gì:**
- Một server có thể phục vụ nhiều client cùng lúc qua multicast.
- Mỗi client nhận cùng một stream mà server không cần tạo kết nối riêng.

**Test phần nào:**
- Phần multicast sender trong `Server.py`
- Phần join/receive/display trong `Client.py`
- Hành vi one-to-many của kiến trúc multicast

**Thực hiện ở đâu:**
- Trên cùng một máy bằng nhiều terminal/cửa sổ client hoặc trên nhiều máy cùng LAN.

**Kịch bản kiểm thử:**

```bash
python3 Server.py movie.Mjpeg
python3 Client.py
python3 Client.py
python3 Client.py
```

**Kỳ vọng:**
- Tất cả client mở được cửa sổ video.
- Tất cả đều nhận cùng luồng multicast `239.1.1.1:5004`.
- Việc đóng một client không làm các client còn lại mất luồng.

**Ý nghĩa:**
- Đây là bài test trực tiếp cho kiến trúc multicast nhiều người xem, đồng thời phục vụ mục rubric “Multiple clients”.

### 5.6. Kiểm thử loss detection (test-only mode)

**Đang test gì:**
- Packet loss statistics và frame loss statistics có hoạt động không khi packet bị drop.

**Test phần nào:**
- Logic drop mô phỏng trong `Client.py`
- Packet loss counting trong `Client.py`
- Frame reassembly và frame loss detection trong `Client.py`

**Thực hiện ở đâu:**
- Chạy trong client bằng tham số mô phỏng mất gói.

**Lệnh kiểm thử:**

```bash
python3 Server.py movie.Mjpeg
python3 Client.py 10
python3 Client.py 15
```

**Những gì cần quan sát:**
- `Packet Loss` trên overlay tăng xấp xỉ mức mô phỏng.
- `Frame Loss` tăng mạnh hơn `Packet Loss` do frame bị hỏng nếu thiếu fragment.
- Video có thể giật hơn nhưng client không crash.

**Ý nghĩa:**
- Bài test này xác nhận phần “loss detection” thực sự có tác dụng chứ không chỉ tồn tại trong code.

### 5.7. Kiểm thử loop video

**Đang test gì:**
- Khi đi tới cuối `movie.Mjpeg`, server có tự động quay lại đầu file và phát tiếp không.

**Test phần nào:**
- `VideoStream.py` với logic EOF handling và reopen file.
- `Server.py` với vòng lặp stream liên tục.

**Thực hiện ở đâu:**
- Chạy server đủ lâu và quan sát client hoặc receiver tiếp tục nhận frame sau khi một vòng video kết thúc.

**Kịch bản kiểm thử:**
- Chạy `python3 Server.py movie.Mjpeg`.
- Để server hoạt động liên tục qua nhiều vòng phát.
- Quan sát client/receiver không dừng sau khi video hết.

**Kỳ vọng:**
- Server không thoát khi video kết thúc.
- Luồng video được phát lại từ đầu tự động.
- Client tiếp tục hiển thị frame mới.

**Ý nghĩa:**
- Đây là bài test trực tiếp cho yêu cầu “Restart the video automatically after reaching the last frame”.

### 5.8. Kiểm thử thoát client và rời multicast group

**Đang test gì:**
- Client có giải phóng tài nguyên đúng khi thoát không.
- Client có rời multicast group đúng yêu cầu không.

**Test phần nào:**
- `cleanup()` trong `Client.py`
- `IP_DROP_MEMBERSHIP`
- đóng socket và hủy cửa sổ OpenCV

**Thực hiện ở đâu:**
- Trong lúc `Client.py` đang chạy và hiển thị video.

**Cách kiểm thử:**
- Nhấn `q` trên cửa sổ video.
- Hoặc đóng trực tiếp cửa sổ OpenCV.

**Kỳ vọng:**
- Client thoát sạch.
- Socket được đóng.
- Multicast group được leave.
- Các client khác nếu đang chạy vẫn tiếp tục hoạt động bình thường.

### 5.9. Rủi ro và giới hạn khi kiểm thử

- `test_multicast.py` là receiver kỹ thuật để quan sát packet, không phải test framework có assertion tự động.
- Kiểm thử giao diện OpenCV cần thực hiện trong môi trường desktop thật.
- Nếu trong cùng mạng có nhiều broadcaster dùng cùng multicast group, số liệu sequence ở receiver có thể nhiễu; đây là giới hạn của môi trường multicast chung, không phải lỗi logic encode/decode.
- Packet loss tự nhiên trên loopback thường gần như bằng 0, vì vậy cơ chế giả lập mất gói ở client là cần thiết để kiểm tra loss detection.

---

## 6. Hướng dẫn cài đặt và vận hành

### 6.1. Yêu cầu môi trường

- Python `3.8+`
- Hệ điều hành hỗ trợ UDP multicast
- Môi trường có giao diện đồ họa nếu muốn chạy `Client.py`

### 6.2. Cài đặt thư viện

```bash
pip install -r requirements.txt
```

`requirements.txt` gồm:
- `opencv-python>=4.5`
- `numpy>=1.19`

### 6.3. Chạy server

```bash
python Server.py movie.Mjpeg
```

### 6.4. Chạy client (mode chuẩn theo đề bài)

```bash
python Client.py
```

Thoát chương trình:
- nhấn `q` trong cửa sổ video
- hoặc đóng cửa sổ OpenCV

### 6.5. Chạy client với giả lập packet loss (test-only mode)

```bash
python Client.py 10
```

Ví dụ trên giả lập mất `10%` packet ở phía client để kiểm tra loss detection.

### 6.6. Chạy receiver test tối giản

```bash
python test_multicast.py
```

Script này phù hợp để:
- kiểm tra nhanh server có phát multicast hay không
- xem log packet nhận được
- xác minh custom packet hoạt động end-to-end

---

## 7. Đối chiếu với rubric chấm điểm

| Hạng mục | Điểm tối đa | Mức độ đáp ứng | Giải thích |
| :--- | :---: | :--- | :--- |
| Server implementation | 2.5 | Đạt | Có multicast sender, đọc MJPEG, fragment frame, gửi UDP multicast, pacing ~20 FPS, tự loop video |
| Client implementation | 2.5 | Đạt | Có join multicast, nhận packet, ghép frame, decode JPEG, hiển thị video, cleanup khi thoát |
| Packet format | 2.0 | Đạt | Có custom packet 12 byte với encode/decode rõ ràng |
| Multiple clients & loss detection | 2.0 | Đạt | Kiến trúc multicast hỗ trợ nhiều client, client có packet loss và frame loss statistics |
| Report | 1.0 | Đạt | Báo cáo mô tả kiến trúc, packet format, cài đặt, kiểm thử, hướng dẫn chạy và đối chiếu rubric |

Nhận xét:
- Về mặt kỹ thuật, repository hiện đã bám sát đầy đủ các yêu cầu chức năng của đề bài.
- Phần còn lại trước khi nộp chính thức chỉ là cập nhật thông tin nhóm nếu giảng viên yêu cầu hiển thị trên trang đầu báo cáo.

---

## 8. Kết luận

Đồ án đã xây dựng thành công một hệ thống **Video Streaming using IP Multicast** theo đúng phạm vi đề bài.

Các kết quả chính đạt được:
- Server đọc file MJPEG theo từng frame và phát multicast tới `239.1.1.1:5004`
- Frame được phân mảnh ở tầng ứng dụng bằng custom packet format
- Client join multicast group, nhận packet, ghép ảnh, giải mã và hiển thị video theo thời gian thực
- Hệ thống có packet loss detection và frame loss detection
- Video tự động loop khi phát hết file
- Đã có kiểm tra end-to-end xác nhận đường truyền multicast hoạt động

Với hiện trạng mã nguồn hiện tại, dự án đã đáp ứng đúng mục tiêu kỹ thuật của bài Project 02 và sẵn sàng cho bước demo/chấm trực tiếp.
