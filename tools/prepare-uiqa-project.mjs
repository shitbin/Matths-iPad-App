// Generated, ignored simulator harness. Use llama source db4480bc802dda303627830833e0e6c2a7c47297.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const framework=process.argv[2];
if(!framework || !['ios-arm64-simulator','ios-arm64_x86_64-simulator'].some(slice=>fs.existsSync(path.join(framework,slice,'llama.framework/llama')))) throw Error('Provide matching db4480b simulator XCFramework');
const dest=path.join(root,'.Matths-UIQA.xcodeproj');
fs.cpSync(path.join(root,'Matths.xcodeproj'),dest,{recursive:true});
const pbx=path.join(dest,'project.pbxproj');
const source=fs.readFileSync(pbx,'utf8');
if(!source.includes('path = Frameworks/llama.xcframework;'))throw Error('Framework reference missing');
fs.writeFileSync(pbx,source.replace('path = Frameworks/llama.xcframework;',`path = "${framework}";`)
 .replaceAll('PRODUCT_BUNDLE_IDENTIFIER = kr.matths.app.widget;','PRODUCT_BUNDLE_IDENTIFIER = kr.matths.app.uiqa.widget;')
 .replaceAll('PRODUCT_BUNDLE_IDENTIFIER = kr.matths.app;','PRODUCT_BUNDLE_IDENTIFIER = kr.matths.app.uiqa;'));
const scheme=path.join(dest,'xcshareddata/xcschemes/Matths.xcscheme');
fs.writeFileSync(scheme,fs.readFileSync(scheme,'utf8').replaceAll('container:Matths.xcodeproj','container:.Matths-UIQA.xcodeproj'));
console.log(dest);
