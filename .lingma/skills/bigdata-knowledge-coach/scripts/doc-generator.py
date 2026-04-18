#!/usr/bin/env python3
"""
技术文档生成器
基于大数据知识库自动生成高质量技术文档
"""

import os
import json
import re
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any

class TechDocGenerator:
    """技术文档生成器"""
    
    def __init__(self, knowledge_base_path: str = "../bigdata"):
        self.knowledge_base_path = Path(knowledge_base_path)
        self.templates = self.load_templates()
        
    def load_templates(self) -> Dict[str, str]:
        """加载文档模板"""
        templates = {
            'tech_review': self.get_tech_review_template(),
            'best_practice': self.get_best_practice_template(),
            'troubleshooting': self.get_troubleshooting_template(),
            'learning_path': self.get_learning_path_template()
        }
        return templates
    
    def get_tech_review_template(self) -> str:
        """技术综述模板"""
        return """# {tech_name}全景技术综述

## 1. 技术概述

### 1.1 核心定义
{tech_overview}

### 1.2 发展历程
{tech_history}

### 1.3 技术特点
{tech_features}

## 2. 架构设计

### 2.1 整体架构
{architecture_diagram}

### 2.2 核心组件
{core_components}

### 2.3 数据流程
{data_flow}

## 3. 核心概念

### 3.1 关键术语
{key_terms}

### 3.2 技术原理
{tech_principles}

### 3.3 最佳实践
{best_practices}

## 4. 应用场景

### 4.1 适用场景
{use_cases}

### 4.2 案例分析
{case_studies}

### 4.3 性能指标
{performance_metrics}

## 5. 对比分析

### 5.1 技术对比
{tech_comparison}

### 5.2 选型建议
{selection_advice}

## 6. 发展趋势

### 6.1 技术演进
{future_trends}

### 6.2 行业应用
{industry_applications}

## 7. 参考资料

{references}

---
*文档生成时间：{generation_time}*
"""
    
    def get_best_practice_template(self) -> str:
        """最佳实践模板"""
        return """# {tech_name}最佳实践指南

## 1. 配置优化

### 1.1 核心配置参数
#### 关键参数说明
{config_parameters}

#### 配置示例
{config_examples}

### 1.2 性能调优
#### JVM调优
{jvm_tuning}

#### 网络调优
{network_tuning}

## 2. 实践规范

### 2.1 代码规范
#### 命名规范
{naming_conventions}

#### 异常处理
{exception_handling}

### 2.2 部署规范
#### 环境准备
{environment_prep}

#### 发布流程
{deployment_process}

## 3. 常见问题

### 3.1 性能问题
{performance_issues}

### 3.2 容错问题
{fault_tolerance}

## 4. 监控指标

### 4.1 关键指标
{key_metrics}

### 4.2 告警配置
{alert_config}

## 5. 参考资料

{references}

---
*文档生成时间：{generation_time}*
"""
    
    def get_troubleshooting_template(self) -> str:
        """故障排查模板"""
        return """# {tech_name}故障排查手册

## 1. 故障分类

### 1.1 性能故障
{performance_faults}

### 1.2 容错故障
{fault_tolerance_faults}

### 1.3 配置故障
{config_faults}

## 2. 故障排查流程

### 2.1 通用排查步骤
{general_steps}

### 2.2 特定故障排查
{specific_troubleshooting}

## 3. 常见故障案例

### 3.1 内存溢出
{memory_overflow}

### 3.2 网络问题
{network_issues}

### 3.3 并发问题
{concurrency_issues}

## 4. 故障预防

### 4.1 监控策略
{monitoring_strategy}

### 4.2 预防措施
{prevention_measures}

## 5. 紧急处理流程

{emergency_procedures}

---
*文档生成时间：{generation_time}*
"""
    
    def get_learning_path_template(self) -> str:
        """学习路径模板"""
        return """# {role_name}学习路径图谱

## 1. 角色定位

### 1.1 职责范围
{role_responsibilities}

### 1.2 能力要求
{skill_requirements}

### 1.3 发展方向
{career_path}

## 2. 学习阶段

### 2.1 基础入门阶段（{phase1_duration}）
{phase1_content}

### 2.2 进阶提升阶段（{phase2_duration}）
{phase2_content}

### 2.3 高级精通阶段（{phase3_duration}）
{phase3_content}

### 2.4 专家架构阶段（{phase4_duration}）
{phase4_content}

## 3. 知识体系

### 3.1 技术栈体系
{tech_stack}

### 3.2 核心知识点
{core_knowledge}

### 3.3 实践项目
{practice_projects}

## 4. 学习建议

### 4.1 学习方法
{learning_methods}

### 4.2 时间规划
{time_planning}

### 4.3 资源推荐
{resource_recommendations}

## 5. 能力评估

### 5.1 评估标准
{evaluation_criteria}

### 5.2 认证路径
{certification_path}

---
*文档生成时间：{generation_time}*
"""
    
    def extract_tech_info(self, tech_name: str) -> Dict[str, Any]:
        """从知识库提取技术信息"""
        tech_info = {
            'tech_name': tech_name,
            'tech_overview': '',
            'tech_history': '',
            'tech_features': '',
            'architecture_diagram': '',
            'core_components': '',
            'data_flow': '',
            'key_terms': '',
            'tech_principles': '',
            'best_practices': '',
            'use_cases': '',
            'case_studies': '',
            'performance_metrics': '',
            'tech_comparison': '',
            'selection_advice': '',
            'future_trends': '',
            'industry_applications': '',
            'references': '',
            'generation_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
        
        # 搜索相关文档
        search_paths = [
            f"{self.knowledge_base_path}/{tech_name}",
            f"{self.knowledge_base_path}/**/*{tech_name}*",
            f"{self.knowledge_base_path}/**/{tech_name.lower()}*"
        ]
        
        # 搜索并提取信息
        for path in search_paths:
            if os.path.exists(path):
                if os.path.isdir(path):
                    # 处理目录
                    for root, dirs, files in os.walk(path):
                        for file in files:
                            if file.endswith('.md'):
                                self._extract_from_file(os.path.join(root, file), tech_info)
                elif path.endswith('.md'):
                    # 处理文件
                    self._extract_from_file(path, tech_info)
        
        return tech_info
    
    def _extract_from_file(self, file_path: str, tech_info: Dict[str, Any]):
        """从单个文件提取信息"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # 简单的关键词匹配和内容提取
            if '概述' in content or '介绍' in content:
                tech_info['tech_overview'] += content[:500] + '\n'
            
            if '历史' in content or '发展' in content:
                tech_info['tech_history'] += content[:500] + '\n'
            
            if '特点' in content or '优势' in content:
                tech_info['tech_features'] += content[:500] + '\n'
                
            if '架构' in content:
                tech_info['architecture_diagram'] += content[:500] + '\n'
            
            if '组件' in content or '核心' in content:
                tech_info['core_components'] += content[:500] + '\n'
            
            # 提取关键词和术语
            if '术语' in content or '概念' in content:
                tech_info['key_terms'] += self._extract_key_terms(content) + '\n'
                
        except Exception as e:
            print(f"Error reading file {file_path}: {e}")
    
    def _extract_key_terms(self, content: str) -> str:
        """提取关键词和术语"""
        # 简单的术语提取
        terms = []
        lines = content.split('\n')
        for line in lines:
            if line.startswith('## ') or line.startswith('### '):
                terms.append(line.replace('#', '').strip())
            elif line.startswith('- ') and len(line) < 100:
                terms.append(line.replace('- ', '').strip())
        
        return '\n'.join(terms[:10])  # 取前10个术语
    
    def generate_doc(self, tech_name: str, doc_type: str, output_path: str):
        """生成文档"""
        if doc_type not in self.templates:
            raise ValueError(f"Unsupported document type: {doc_type}")
        
        # 提取技术信息
        tech_info = self.extract_tech_info(tech_name)
        
        # 获取模板
        template = self.templates[doc_type]
        
        # 填充模板
        doc_content = template.format(**tech_info)
        
        # 添加默认值用于未填充的字段
        default_values = {
            'references': '- [官方文档](https://example.com)\n- [技术博客](https://blog.example.com)',
        }
        
        for key, value in default_values.items():
            if key in doc_content and '{' + key + '}' in doc_content:
                doc_content = doc_content.replace('{' + key + '}', value)
        
        # 写入文件
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(doc_content)
        
        print(f"文档生成成功: {output_path}")
        return doc_content
    
    def batch_generate(self, components: List[str], doc_type: str, output_dir: str):
        """批量生成文档"""
        os.makedirs(output_dir, exist_ok=True)
        
        for component in components:
            output_path = os.path.join(output_dir, f"{component}-{doc_type}.md")
            try:
                self.generate_doc(component, doc_type, output_path)
            except Exception as e:
                print(f"生成 {component} 文档失败: {e}")

def main():
    parser = argparse.ArgumentParser(description='技术文档生成器')
    parser.add_argument('--tech', required=True, help='技术名称')
    parser.add_argument('--type', choices=['tech_review', 'best_practice', 'troubleshooting', 'learning_path'], 
                       default='tech_review', help='文档类型')
    parser.add_argument('--output', required=True, help='输出路径')
    parser.add_argument('--knowledge-base', default='../bigdata', help='知识库路径')
    parser.add_argument('--batch', nargs='+', help='批量生成组件列表')
    parser.add_argument('--output-dir', help='批量输出目录')
    
    args = parser.parse_args()
    
    generator = TechDocGenerator(args.knowledge_base)
    
    if args.batch:
        # 批量生成
        generator.batch_generate(args.batch, args.type, args.output_dir)
    else:
        # 单个生成
        generator.generate_doc(args.tech, args.type, args.output)

if __name__ == '__main__':
    main()