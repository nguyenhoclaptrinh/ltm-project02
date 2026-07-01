# Requirements Checklist and Update Log

This file tracks how the repository matches `Multicast_Video_Streaming_Project_Requirement.docx` and records the updates applied on 2026-07-01.

## Source of Truth

Requirement document: `Multicast_Video_Streaming_Project_Requirement.docx`

Key requirements from the document:
- Server reads MJPEG frame by frame.
- Server packetizes each frame and sends to multicast group `239.1.1.1:5004`.
- Server streams at about 20 FPS and loops automatically when the video ends.
- Client joins multicast group, receives packets, decodes them, displays video, and leaves group on exit.
- Grading rubric: server `2.5`, client `2.5`, packet format `2.0`, multiple clients and loss detection `2.0`, report `1.0`.

## Updates Applied on 2026-07-01

1. Fixed long-running stream behavior to stay consistent with the 2-byte `Frame ID` defined in the custom packet header.
2. Updated the report to document the `Frame ID` wrap behavior and to expand the testing section so each test states what it is validating, which component it covers, and where it is run.
3. Added trace/checklist documents and moved all Markdown documentation into `.docs`.
4. Added helper scripts for running the app and packaging the source submission.

## Requirement Compliance Matrix

| Requirement from doc | Status | Evidence in repo | Notes |
| :--- | :--- | :--- | :--- |
| Read MJPEG video file frame by frame | Done | `VideoStream.py` parses JPEG SOI/EOI markers and returns one frame at a time. See `nextFrame()` in [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:27). | The implementation reads raw MJPEG, not containerized video formats. |
| Packetize each frame | Done | Frame data is fragmented by `MAX_PAYLOAD_SIZE = 1400` in [Server.py](/home/chung/Desktop/ltm-project02/Server.py:17) and [Server.py](/home/chung/Desktop/ltm-project02/Server.py:57). | This matches the custom packet requirement and avoids large UDP payloads. |
| Send every frame to a multicast IP address | Done | Multicast target is `239.1.1.1:5004` in [Server.py](/home/chung/Desktop/ltm-project02/Server.py:15) and packets are sent with `sendto()` in [Server.py](/home/chung/Desktop/ltm-project02/Server.py:79). | Verified by local receiver test. |
| Broadcast at approximately 20 FPS | Done | `time.sleep(0.05)` in [Server.py](/home/chung/Desktop/ltm-project02/Server.py:83). | Approximate frame pacing as requested by the doc. |
| Continue streaming until video ends | Done | Main server loop is `while True` in [Server.py](/home/chung/Desktop/ltm-project02/Server.py:45). | Combined with MJPEG looping logic below. |
| Restart video automatically after the last frame | Done | `VideoStream.open_file()` is called again when EOF is reached in [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:35) and [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:66). | Updated server/client handling to remain safe when `Frame ID` wraps after `65535`. |
| Join multicast group | Done | `IP_ADD_MEMBERSHIP` is used in [Client.py](/home/chung/Desktop/ltm-project02/Client.py:62). | Client binds to `0.0.0.0:5004`. |
| Receive multicast packets | Done | Receiver loop reads UDP packets in [Client.py](/home/chung/Desktop/ltm-project02/Client.py:81) and [Client.py](/home/chung/Desktop/ltm-project02/Client.py:89). | Receiver thread prevents UI blocking. |
| Decode received packets | Done | Custom packet decoding is implemented in [Packet.py](/home/chung/Desktop/ltm-project02/Packet.py:45), then reassembly occurs in [Client.py](/home/chung/Desktop/ltm-project02/Client.py:115). | Packet header format matches the document. |
| Display video in real time | Done | JPEG bytes are decoded with OpenCV and shown via `cv2.imshow` in [Client.py](/home/chung/Desktop/ltm-project02/Client.py:183) and [Client.py](/home/chung/Desktop/ltm-project02/Client.py:212). | GUI behavior still requires manual demo in a desktop session. |
| Leave multicast group when exiting | Done | `IP_DROP_MEMBERSHIP` is called in [Client.py](/home/chung/Desktop/ltm-project02/Client.py:239). | Cleanup also closes the socket and destroys OpenCV windows. |

## Rubric Mapping

| Rubric item | Points | Status | Evidence |
| :--- | :---: | :--- | :--- |
| Server implementation | 2.5 | Strong | Multicast UDP sender, frame fragmentation, 20 FPS pacing, automatic looping. See [Server.py](/home/chung/Desktop/ltm-project02/Server.py:33), [Server.py](/home/chung/Desktop/ltm-project02/Server.py:57), [VideoStream.py](/home/chung/Desktop/ltm-project02/VideoStream.py:27). |
| Client implementation | 2.5 | Strong | Multicast join, receiver thread, reassembly, OpenCV display, cleanup on exit. See [Client.py](/home/chung/Desktop/ltm-project02/Client.py:51), [Client.py](/home/chung/Desktop/ltm-project02/Client.py:81), [Client.py](/home/chung/Desktop/ltm-project02/Client.py:172), [Client.py](/home/chung/Desktop/ltm-project02/Client.py:231). |
| Packet format | 2.0 | Strong | Custom 12-byte header defined and encoded/decoded in [Packet.py](/home/chung/Desktop/ltm-project02/Packet.py:3). |
| Multiple clients and loss detection | 2.0 | Mostly done | Loss statistics are implemented in [Client.py](/home/chung/Desktop/ltm-project02/Client.py:98) and frame-loss tracking in [Client.py](/home/chung/Desktop/ltm-project02/Client.py:115). Multicast semantics allow multiple clients on the same group. Full multi-client proof still needs a manual demo or screenshots. |
| Report | 1.0 | Mostly done | Technical explanation exists in [Report.md](/home/chung/Desktop/ltm-project02/.docs/Report.md:12) onward. The report includes the `Frame ID` wrap note and a detailed testing section with explicit test coverage. Team metadata placeholders still need to be filled by the group. |

## Code Changes Made

### 1. Server-side `Frame ID` safety
- Added `FRAME_ID_MODULO = 1 << 16` in [Server.py](/home/chung/Desktop/ltm-project02/Server.py:18).
- Server now sends `video_stream.frameNbr() % FRAME_ID_MODULO` in [Server.py](/home/chung/Desktop/ltm-project02/Server.py:54).
- Reason: the packet header allocates only 2 bytes for `Frame ID`, so streaming longer than `65535` frames must wrap intentionally instead of crashing.

### 2. Client-side `Frame ID` unwrap logic
- Added `FRAME_ID_MODULO`, `FRAME_WRAP_THRESHOLD`, `last_raw_frame_id`, and `frame_id_wrap_count` in [Client.py](/home/chung/Desktop/ltm-project02/Client.py:21) and [Client.py](/home/chung/Desktop/ltm-project02/Client.py:41).
- Added `expand_frame_id()` in [Client.py](/home/chung/Desktop/ltm-project02/Client.py:69).
- Client now converts the 2-byte transmitted `Frame ID` back into a monotonic internal counter before frame-loss accounting in [Client.py](/home/chung/Desktop/ltm-project02/Client.py:116).
- Reason: without this, the client would treat wrapped frames as old packets and stop tracking frames correctly after about 54.6 minutes at 20 FPS.

### 3. Report and documentation alignment
- Added the `Frame ID` limit note in [Report.md](/home/chung/Desktop/ltm-project02/.docs/Report.md:110).
- Expanded the testing section in [Report.md](/home/chung/Desktop/ltm-project02/.docs/Report.md:230) so each test clearly states what is being tested, which subsystem it covers, where it is run, and why it matters.
- Moved Markdown documentation into `.docs/`.

### 4. Helper scripts
- Added [run_app.sh](/home/chung/Desktop/ltm-project02/scripts/run_app.sh:1) to run `server`, `client`, or `test` modes from one entry point.
- Added [package_source.sh](/home/chung/Desktop/ltm-project02/scripts/package_source.sh:1) to create a clean `source/` folder for submission without reports.

## Verification Performed

Checks run locally in this workspace:
- `python3 -m py_compile Server.py Client.py Packet.py VideoStream.py test_multicast.py`
- `python3 Server.py movie.Mjpeg` together with `python3 test_multicast.py`

Observed end-to-end result:
- Receiver joined `239.1.1.1:5004` successfully.
- Receiver got `30/30` packets in sequence during the stable local receiver run used for validation.
- Sample packets showed correct `GlobalSeq`, `FrameID`, fragment counts, and payload sizes.
- Reported `LossRate=0.00%` during the stable local receiver test.

## Remaining Manual Items Before Submission

- Replace the placeholder group information in [Report.md](/home/chung/Desktop/ltm-project02/.docs/Report.md:7).
- Capture screenshots or a short demo of two or more clients receiving the same multicast stream at the same time if the instructor expects proof beyond code inspection.
- Run `Client.py` in a desktop session to manually confirm OpenCV display and exit behavior with `q`.

## Submission Readiness

Current assessment after the updates:
- Core functional requirements: satisfied.
- Major technical risk found during review: fixed.
- Main remaining gaps: group metadata and stronger proof for multi-client demo.
