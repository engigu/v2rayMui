

# 先构建前端资源

cd server/web
npm run build
cd ../..

# 然后构建后端
cd server
go build -o v2rayMuiGoServer main.go
cd ../

echo $(pwd)
# 然后移动到resources目录
cp server/v2rayMuiGoServer ./v2rayMui/Resources/bin/
rm -rf server/v2rayMuiGoServer

echo $(ls v2rayMui/Resources/bin/)
# # 然后构建v2rayMui
# xcodebuild -project v2rayMui.xcodeproj -scheme v2rayMui -configuration Release
# cd ..