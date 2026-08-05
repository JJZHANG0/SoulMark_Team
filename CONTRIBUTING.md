# SoulMark 协作流程

为了避免多人同时更新 `main` 时互相覆盖，每项工作使用独立分支和 Pull Request。

## 开始开发

```bash
git switch main
git pull --ff-only origin main
git switch -c feature/你的名字-功能名
```

## 提交与上传

```bash
git add <本次修改的文件>
git commit -m "feat: 简短说明"
git push -u origin feature/你的名字-功能名
```

随后在 GitHub 创建 Pull Request，确认构建和测试通过后再合并到 `main`。

## 同步其他人的更新

```bash
git fetch origin
git rebase origin/main
```

遇到冲突时只处理业务文件，不提交 `.idea`、`xcuserdata`、`.env`、本地数据库、上传目录或构建产物。
