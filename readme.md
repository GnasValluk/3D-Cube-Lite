GAME DESIGN DOCUMENT (GDD) - BASE PROJECT SPECIFICATION
1. TỔNG QUAN DỰ ÁN (PROJECT OVERVIEW)
Tên dự án (Tạm thời): Project Cubic-Life

Engine: Godot Engine 4.x

Thể loại: Thám hiểm / Sinh tồn / Định hình bằng thuật toán (Procedural Adventure)

Góc nhìn đồ họa: Top-Down Isometric 3D (Góc nhìn từ trên xuống, lệch một góc 45 độ đặc trưng của game chiến thuật/xây dựng, tạo cảm giác không gian 3D lập phương).

Phong cách nghệ thuật (Art Style): No-Assets / Pure Voxel & Procedural Art. Toàn bộ thế giới, nhân vật, môi trường đều được cấu thành từ các khối hình học cơ bản (BoxMesh, CylinderMesh) có sẵn trong Godot. Không sử dụng file model 3D bên ngoài (.gltf, .obj) hay texture vẽ tay.

2. KIẾN TRÚC ĐỒ HỌA & CAMERA (GRAPHICS & CAMERA SETUP)
2.1. Cấu hình Camera Isometric
Kiểu Camera: Camera3D đặt ở chế độ Orthographic (để triệt tiêu điểm tụ, giữ các cạnh lập phương luôn song song) hoặc Perspective với tiêu cự xa (Fov thấp) để tạo độ sâu nhẹ tùy chỉnh.

Góc quay cố định: * Trục X (Pitch): Quay xuống khoảng -35.264 độ.

Trục Y (Yaw): Quay ngang một góc 45 độ.

Hành vi Camera: Lerp (nội suy) đi theo nhân vật chính một khoảng cách cố định (Camera SpringArm3D).

2.2. Thẩm mỹ & Hiệu ứng trực quan (Visuals & Shaders)
Ánh sáng (Lighting): Sử dụng một DirectionalLight3D làm ánh sáng mặt trời, kích hoạt đổ bóng sắc nét (Shadow Max Distance thấp để tăng độ nét của bóng khối lập phương).

Đổ màu (Coloring): Dùng StandardMaterial3D với chế độ màu phẳng (Flat/Albedo Color), tắt tính năng phản chiếu (Roughness = 1.0, Specular = 0.0) để tạo cảm giác đồ chơi lego/khối nhựa cũ.

Hiệu ứng Hạt (Particles): Hệ thống hạt GPUParticles3D sử dụng các khối lập phương siêu nhỏ để làm hiệu ứng bụi khi di chuyển, hiệu ứng vỡ vụn khi tài nguyên bị phá hủy.

3. HỆ THỐNG NHÂN VẬT & DI CHUYỂN (CHARACTER & PROCEDURAL ANIMATION)
3.1. Cấu trúc Phân cấp Nhân vật (Ví dụ: Con Thỏ - Rabbit Base)
Nhân vật được lắp ráp theo cấu trúc cây Node (Parent - Child) để tận dụng tính kế thừa tọa độ:

CharacterBody3D (Gốc quản lý vật lý và di chuyển chính)

CollisionShape3D (Hộp va chạm)

MeshInstance3D (Thân - Khối hộp lớn trung tâm)

MeshInstance3D (Đầu - Khối hộp nhỏ hơn đặt phía trước)

MeshInstance3D (Tai trái - Khối hộp thuôn dài)

MeshInstance3D (Tai phải - Khối hộp thuôn dài)

MeshInstance3D (Chân trước/sau - Các khối hộp nhỏ ở dưới đáy)

3.2. Hệ thống Hoạt ảnh bằng Thuật toán (Procedural Animation Logic)
Không sử dụng Skeleton3D hay Xương (Bones).

Chuyển động dựa trên trạng thái (State) của nhân vật được tính toán trong _physics_process(delta):

Trạng thái Đứng yên (Idle): Các bộ phận co giãn nhẹ (Breathing effect) bằng hàm sin(time) tác động vào thuộc tính scale.y và position.y của khối Thân.

Trạng thái Di chuyển (Walk/Jump): * Khối Thân di chuyển nhấp nhô theo hàm trục tọa độ Y = abs(sin(time_passed * speed)).

Các khối Tai và Chân tự động xoay quanh trục (Rotation) theo hàm cos(time_passed) nghịch pha với Thân để tạo độ trễ sinh học (quán tính chuyển động).

4. CƠ CHẾ LẬP TRÌNH CỐT LÕI (CORE GAMEPLAY SYSTEMS)
4.1. Hệ thống Điều khiển (Input System)
Hỗ trợ di chuyển 4 hướng hoặc 8 hướng bằng phím W, A, S, D hoặc Mũi tên.

Vì góc camera quay lệch 45 độ (Isometric), Vector di chuyển đầu vào (Input Vector) cần được xoay một góc 45 độ tương ứng với góc của Camera để đảm bảo khi người chơi bấm nút "Lên" (W), nhân vật sẽ đi chéo lên theo đúng hướng màn hình hiển thị.

4.2. Khởi tạo Thế giới (Procedural World Generation Base)
Môi trường (Mặt đất, Cây cối, Đá) được sinh ra bằng mã nguồn.

Sử dụng vòng lặp for để rải các khối BoxMesh tạo thành lưới mặt đất (Grid-based map).

Ứng dụng thuật toán nhiễu ngẫu nhiên (FastNoiseLite) để quy định độ cao (Trục Y) của các khối đất, tạo ra các ngọn đồi hoặc thung lũng gồ ghề dạng bậc thang (Stepped terrain).

5. HƯỚNG DẪN KHỞI TẠO DỰ ÁN CHO AI TRỢ LÝ (PROMPT FOR AI ASSISTANT)
Bạn hãy sao chép đoạn lệnh dưới đây để đưa vào AI của bạn:

"Dựa trên tài liệu GDD ở trên, hãy tạo cho tôi cấu trúc code cơ bản (GDScript) cho Godot 4. Viết một Script dành cho nhân vật chính kế thừa từ CharacterBody3D. Script này phải bao gồm:

Xử lý di chuyển bằng phím WASD đã được xoay góc 45 độ để chuẩn hóa theo góc nhìn Isometric Top-Down.

Hàm toán học lượng giác lượng biến thiên theo thời gian (sin/cos) áp dụng vào các Node con để tạo hoạt ảnh nhảy nhấp nhô (Procedural Animation) khi nhân vật có vận tốc (Velocity > 0). Hãy chú thích rõ ràng cách tổ chức cây Node trong code."

Bạn có thể lưu tài liệu này thành một file .md (Markdown) hoặc .txt để gửi cho trợ lý AI. Nó đã chứa đầy đủ từ khóa chuyên ngành (Isometric, Orthographic, Procedural Animation, BoxMesh) để AI hiểu và thiết kế cho bạn một bộ code mẫu chuẩn xác nhất!