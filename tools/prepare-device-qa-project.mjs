// Isolated device build: preserves the installed app, URL ownership and group data.
// No production Apple Sign In/IAP/AAC/Universal Links verdict may use this harness.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dest=path.join(root,'.Matths-DeviceQA.xcodeproj');
fs.cpSync(path.join(root,'Matths.xcodeproj'),dest,{recursive:true});
const empty='<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict/></plist>\n';
fs.writeFileSync(path.join(dest,'QA.entitlements'),empty);
fs.writeFileSync(path.join(dest,'QA-Info.plist'),fs.readFileSync(path.join(root,'Info.plist'),'utf8').replace('<string>matths</string>','<string>matths-uiqa</string>'));
const pbx=path.join(dest,'project.pbxproj');
const source=fs.readFileSync(pbx,'utf8')
 .replaceAll('PRODUCT_BUNDLE_IDENTIFIER = kr.matths.app.widget;','PRODUCT_BUNDLE_IDENTIFIER = kr.matths.app.uiqa.widget;')
 .replaceAll('PRODUCT_BUNDLE_IDENTIFIER = kr.matths.app;','PRODUCT_BUNDLE_IDENTIFIER = kr.matths.app.uiqa;')
 .replaceAll('INFOPLIST_KEY_CFBundleDisplayName = Matths;','INFOPLIST_KEY_CFBundleDisplayName = "Matths QA";')
 .replaceAll('CODE_SIGN_ENTITLEMENTS = Matths/MatthsApp.entitlements;','CODE_SIGN_ENTITLEMENTS = ".Matths-DeviceQA.xcodeproj/QA.entitlements";')
 .replaceAll('CODE_SIGN_ENTITLEMENTS = MatthsWidget/MatthsWidget.entitlements;','CODE_SIGN_ENTITLEMENTS = ".Matths-DeviceQA.xcodeproj/QA.entitlements";')
 .replaceAll('INFOPLIST_FILE = Info.plist;','INFOPLIST_FILE = ".Matths-DeviceQA.xcodeproj/QA-Info.plist";');
fs.writeFileSync(pbx,source);
const scheme=path.join(dest,'xcshareddata/xcschemes/Matths.xcscheme');
fs.writeFileSync(scheme,fs.readFileSync(scheme,'utf8').replaceAll('container:Matths.xcodeproj','container:.Matths-DeviceQA.xcodeproj'));
console.log(dest);
