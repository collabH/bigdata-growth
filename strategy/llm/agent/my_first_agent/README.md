# 我的第一个智能体

## 前置依赖

* Python环境
```bash
# 进入项目目录
cd "my_first_agent"

# 创建虚拟环境
python -m venv venv

# 激活虚拟环境
# macOS/Linux:
source venv/bin/activate
```

* 安装依赖
```python
# 安装核心依赖
pip install "requests>=2.31.0"
pip install "tavily-python>=0.3.0"
pip install "openai>=1.0.0"

# 可选：安装其他常用包
pip install "python-dotenv>=1.0.0"
```
* 环境变量
```bash
# 创建 .env 文件
touch .env

# 编辑 .env 文件，添加以下内容
# Tavily API 配置
TAVILY_API_KEY=your_tavily_api_key

# 大语言模型 API 配置（选择其中一种）
# 选项一：AIHubmix
OPENAI_API_KEY=your_aihubmix_api_key
OPENAI_BASE_URL=https://aihubmix.com/v1
MODEL_NAME=xxxx
```