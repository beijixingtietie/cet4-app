# CET4 备考助手 - 云端部署指南

## 方案一：GitHub Pages（推荐，免费永久托管）

### 步骤 1：在 GitHub 创建仓库

1. 打开 https://github.com/new
2. 仓库名称填写：`cet4-web`
3. 选择 **Public**（公开）
4. 不要勾选 "Add a README file"
5. 点击 **Create repository**

### 步骤 2：推送代码到 GitHub

在 PowerShell 中运行以下命令（已配置好，直接复制粘贴）：

```powershell
cd C:\Users\10713\Desktop\CET4_English\cet4_app\build\web
git remote add origin https://github.com/10713/cet4-web.git
git branch -M main
git push -u origin main
```

> 注意：推送时会要求输入 GitHub 用户名和个人访问令牌（Token），不是密码！

#### 如何创建 GitHub Token：
1. 打开 https://github.com/settings/tokens
2. 点击 **Generate new token (classic)**
3. 勾选 `repo` 权限
4. 点击 Generate token
5. 复制生成的 token（只显示一次）

### 步骤 3：启用 GitHub Pages

1. 打开你的仓库页面：`https://github.com/10713/cet4-web`
2. 点击 **Settings** 标签
3. 左侧菜单选择 **Pages**
4. **Source** 选择 **Deploy from a branch**
5. **Branch** 选择 `main`，文件夹选择 `/(root)`
6. 点击 **Save**

### 步骤 4：访问你的应用

等待 1-2 分钟后，访问：

```
https://10713.github.io/cet4-web
```

---

## 方案二：Vercel（推荐，全球 CDN，自动部署）

### 步骤 1：安装 Vercel CLI

```powershell
npm i -g vercel
```

### 步骤 2：部署

```powershell
cd C:\Users\10713\Desktop\CET4_English\cet4_app\build\web
vercel --prod
```

按提示登录 Vercel 账号（可用 GitHub 账号直接登录）。

部署完成后会获得类似 `https://cet4-web.vercel.app` 的地址。

---

## 方案三：Netlify（拖拽部署，最简单）

1. 打开 https://app.netlify.com/drop
2. 将 `C:\Users\10713\Desktop\CET4_English\cet4_app\build\web` 文件夹直接拖拽到网页上
3. 自动部署完成，立即获得访问地址

---

## 方案四：本地临时公网访问（无需注册任何账号）

使用 ngrok 或 cloudflared 暴露本地服务器：

```powershell
# 先启动本地服务器
cd C:\Users\10713\Desktop\CET4_English\cet4_app\build\web
npx serve -l 8080

# 另开一个终端，安装并运行 ngrok
npm i -g ngrok
ngrok http 8080
```

会获得一个类似 `https://xxxx.ngrok-free.app` 的公网地址，任何人都可以访问。

---

## 当前构建状态

- 构建目录：`C:\Users\10713\Desktop\CET4_English\cet4_app\build\web`
- Git 仓库：已初始化并提交
- 文件数量：44 个文件（包含 Flutter Web 运行时、资源文件、数据文件）
- 应用大小：约 8MB（含 CanvasKit WASM）

## 注意事项

1. **API 密钥**：部署到公网后，AI 功能需要配置有效的 API 密钥。当前代码中的 API 配置在 `lib/utils/claude_api.dart` 中。
2. **Web 兼容性**：部分原生功能（如本地通知、音频播放）在 Web 端可能受限。
3. **数据存储**：Web 端使用 `shared_preferences` 的 Web 实现，数据存储在浏览器 LocalStorage 中。
