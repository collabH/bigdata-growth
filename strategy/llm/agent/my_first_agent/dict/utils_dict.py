# 将所有工具函数放入一个字典，方便后续调用
from utils.weather_utils import get_weather
from utils.search_att_utils import get_attraction

available_tools = {
    "get_weather": get_weather,
    "get_attraction": get_attraction,
}
