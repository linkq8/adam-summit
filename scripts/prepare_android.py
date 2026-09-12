"""Apply TV metadata and use installed build-tools after template installation."""
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
build = root / 'android' / 'build'
config = build / 'config.gradle'
config.write_text(config.read_text().replace("buildTools         : '36.1.0'", "buildTools         : '36.0.0'"))
android = 'http://schemas.android.com/apk/res/android'
tools = 'http://schemas.android.com/tools'
ET.register_namespace('android', android)
ET.register_namespace('tools', tools)
manifest = build / 'src/main/AndroidManifest.xml'
tree = ET.parse(manifest)
document = tree.getroot()
for name in ['android.hardware.touchscreen', 'android.hardware.faketouch', 'android.software.leanback']:
    existing = next((e for e in document.findall('uses-feature') if e.get('{'+android+'}name') == name), None)
    if existing is None:
        existing = ET.SubElement(document, 'uses-feature')
    existing.set('{'+android+'}name', name)
    existing.set('{'+android+'}required', 'false')
document.find('application').set('{'+android+'}banner', '@drawable/tv_banner')
tree.write(manifest, encoding='utf-8', xml_declaration=True)
banner = build / 'res/drawable/tv_banner.xml'
banner.parent.mkdir(parents=True, exist_ok=True)
banner.write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="320dp" android:height="180dp" android:viewportWidth="320" android:viewportHeight="180">
<path android:fillColor="#287b68" android:pathData="M0,0H320V180H0Z"/>
<path android:fillColor="#195e54" android:pathData="M0,180L70,75L125,140L202,34L320,180Z"/>
<path android:fillColor="#ffcf55" android:pathData="M160,30L176,66L215,70L186,97L194,136L160,117L126,136L134,97L105,70L144,66Z"/>
<path android:fillColor="#60c4d7" android:pathData="M36,148H108V158H36Z"/>
<path android:fillColor="#ff9a68" android:pathData="M212,148H284V158H212Z"/>
</vector>''')
print('Android TV metadata prepared; touch and leanback are optional.')

java = build / 'src/main/java/com/godot/game/GodotApp.java'
source = java.read_text()
if '// Adam device profile' not in source:
    source = source.replace('public class GodotApp extends GodotActivity {', 'public class GodotApp extends GodotActivity {\n    // Adam device profile: TV is identified by Android, never by screen width.\n    private boolean isTelevision() {\n        android.app.UiModeManager mode = (android.app.UiModeManager)getSystemService(UI_MODE_SERVICE);\n        return mode != null && mode.getCurrentModeType() == android.content.res.Configuration.UI_MODE_TYPE_TELEVISION;\n    }\n    @Override public java.util.List<String> getCommandLine() {\n        java.util.List<String> args = new java.util.ArrayList<>(super.getCommandLine());\n        if (isTelevision()) { args.add("--"); args.add("--tv-device"); }\n        return args;\n    }\n')
    java.write_text(source)
