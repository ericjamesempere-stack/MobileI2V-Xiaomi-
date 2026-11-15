@tool
extends EditorPlugin

var export_plugin: EditorExportPlugin

func _enter_tree() -> void:
    export_plugin = EncoderExportPlugin.new()
    add_export_plugin(export_plugin)

func _exit_tree() -> void:
    remove_export_plugin(export_plugin)
    export_plugin = null

class EncoderExportPlugin extends EditorExportPlugin:
    func _supports_platform(platform: EditorExportPlatform) -> bool:
        return platform is EditorExportPlatformAndroid

    func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
        var aar := "res://addons/mobilei2v_encoder/mobilei2v_encoder.aar"
        if FileAccess.file_exists(aar):
            return PackedStringArray([aar])
        return PackedStringArray()
