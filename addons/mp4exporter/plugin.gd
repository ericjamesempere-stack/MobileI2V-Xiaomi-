@tool
extends EditorPlugin

var android_export: EditorExportPlugin

func _enter_tree() -> void:
    android_export = AndroidExportPlugin.new()
    add_export_plugin(android_export)

func _exit_tree() -> void:
    if android_export != null:
        remove_export_plugin(android_export)
        android_export = null

class AndroidExportPlugin extends EditorExportPlugin:
    func _supports_platform(platform: EditorExportPlatform) -> bool:
        return platform is EditorExportPlatformAndroid

    func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
        return PackedStringArray(["res://addons/mp4exporter/mp4exporter.aar"])
