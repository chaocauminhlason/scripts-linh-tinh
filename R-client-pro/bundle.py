import os

def bundle():
    # Danh sách các file cần gộp theo đúng thứ tự
    core_files = [
        'core/utilities.txt',
        'core/system_controller.txt',
        'core/webhook.txt',
        'core/localization.txt',
        'core/config_manager.txt'
    ]
    
    feature_files = [
        'features/farm.txt',
        'features/boss_hunt.txt',
        'features/server_manager.txt',
        'features/shops_and_guis.txt',
        'features/auto_dungeon.txt',
        'features/tracker.txt',
        'features/hatch_egg.txt',
        'features/auto_rift.txt',
        'features/optimization.txt',
        'features/ai_assistant.txt',
        'features/auto_event.txt'
    ]

    base_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(base_dir, 'build')
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, 'R-Client-Pro-Bundle.lua')

    print("=== Start bundling scripts ===")
    
    bundle_content = []
    bundle_content.append("-- ====================================================================")
    bundle_content.append("-- R-CLIENT PRO BUNDLE (AUTO-BUNDLED ALL MODULES)")
    bundle_content.append("-- ====================================================================\n")
    
    # 1. Khởi tạo bảng chứa tất cả module
    bundle_content.append("local modules = {}")
    
    # 2. Đọc và nhúng code của từng file vào bảng modules
    all_files = core_files + feature_files
    for file_rel_path in all_files:
        file_path = os.path.join(base_dir, file_rel_path)
        if not os.path.exists(file_path):
            print(f"[Warning] File not found: {file_rel_path}, skipping.")
            continue
            
        print(f"-> Loading: {file_rel_path}")
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Bọc toàn bộ code của file vào một function
        bundle_content.append(f"\nmodules['{file_rel_path}'] = function(...)")
        bundle_content.append(content)
        bundle_content.append("end")

    # 3. Đọc nội dung main.txt
    main_path = os.path.join(base_dir, 'main.txt')
    if not os.path.exists(main_path):
        print("[Error] main.txt not found!")
        return
        
    print("-> Loading: main.txt (Main Loader)")
    with open(main_path, 'r', encoding='utf-8') as f:
        main_content = f.read()

    # 4. Định nghĩa lại hàm SafeLoad và nhúng nội dung main.txt
    # Ta sẽ thay thế định nghĩa SafeLoad gốc bằng SafeLoad đọc từ bảng modules cục bộ
    custom_safeload_code = """
-- ==========================================
-- HÀM TẢI LOCAL IN-MEMORY (BYPASS HTTP)
-- ==========================================
local function SafeLoad(filePath)
    local moduleFunc = modules[filePath]
    if moduleFunc then
        -- Kế thừa môi trường hiện tại cho module con
        setfenv(moduleFunc, getfenv(1))
        local success, result = pcall(moduleFunc)
        if success then
            return result
        else
            warn("❌ Lỗi thực thi module " .. filePath .. ": " .. tostring(result))
        end
    else
        warn("⚠️ Không tìm thấy module trong Bundle: " .. filePath)
    end
    return nil
end
"""
    
    # Loại bỏ định nghĩa SafeLoad cũ trong main_content
    # Tìm và cắt bỏ phần hàm SafeLoad cũ trong main_content để thay bằng hàm mới
    import_start = main_content.find("local function SafeLoad")
    if import_start != -1:
        # Tìm vị trí kết thúc của hàm SafeLoad (end cuối cùng trước các file core)
        # Ta sẽ đơn giản là xóa từ 'local function SafeLoad' tới dòng '-- 1. Kéo các file Core'
        anchor = "-- 1. Kéo các file Core"
        anchor_idx = main_content.find(anchor)
        if anchor_idx != -1:
            main_content = main_content[:import_start] + custom_safeload_code + "\n" + main_content[anchor_idx:]
        else:
            print("[Warning] Could not find anchor, prepending custom SafeLoad.")
            main_content = custom_safeload_code + "\n" + main_content

    bundle_content.append("\n-- ========================================== --")
    bundle_content.append("-- MAIN LOADER START                          --")
    bundle_content.append("-- ========================================== --")
    bundle_content.append(main_content)

    # 5. Ghi ra file bundle hoàn chỉnh
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(bundle_content))
        
    print(f"=== Bundled successfully! Output saved to: {output_path} ===")

if __name__ == '__main__':
    bundle()
