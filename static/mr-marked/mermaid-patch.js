/**
 * Mermaid v10.9.0 初始化补丁
 * 修复中文和emoji渲染问题
 */

// 等待DOM和Mermaid加载完成
(function() {
    // 保存原始的mermaid.initialize函数
    if (typeof window.mermaid !== 'undefined') {
        const originalInit = window.mermaid.initialize;

        // 覆盖initialize函数
        window.mermaid.initialize = function(config) {
            // 合并配置，添加对中文和emoji的支持
            const enhancedConfig = {
                ...config,
                startOnLoad: false,
                securityLevel: 'loose',
                theme: 'default',
                themeVariables: {
                    primaryColor: '#f9f9f9',
                    primaryTextColor: '#333',
                    primaryBorderColor: '#7C0000',
                    lineColor: '#F8B229',
                    secondaryColor: '#006100',
                    tertiaryColor: '#fff',
                    fontFamily: 'system-ui, -apple-system, "微软雅黑", "Microsoft YaHei", "Segoe UI", Roboto, "Helvetica Neue", "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"'
                },
                flowchart: {
                    useMaxWidth: true,
                    htmlLabels: true,
                    curve: 'basis',
                    rankSpacing: 50,
                    nodeSpacing: 50,
                    defaultRenderer: 'dagre-d3'
                },
                sequence: {
                    diagramMarginX: 50,
                    diagramMarginY: 10,
                    actorMargin: 50,
                    width: 150,
                    height: 65,
                    boxMargin: 10,
                    boxTextMargin: 5,
                    noteMargin: 10,
                    messageMargin: 35,
                    mirrorActors: true,
                    bottomMarginAdj: 1,
                    useMaxWidth: true
                },
                gantt: {
                    titleTopMargin: 25,
                    barHeight: 20,
                    barGap: 4,
                    topPadding: 50,
                    leftPadding: 75,
                    gridLineStartPadding: 35,
                    fontSize: 11,
                    fontFamily: '"微软雅黑", "Microsoft YaHei", Arial, sans-serif',
                    numberSectionStyles: 4,
                    axisFormat: '%Y-%m-%d'
                },
                pie: {
                    useMaxWidth: true,
                    textPosition: 0.5
                },
                fontFamily: 'system-ui, -apple-system, "微软雅黑", "Microsoft YaHei", "Segoe UI", Roboto, "Helvetica Neue", "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"'
            };

            // 调用原始函数
            if (originalInit) {
                originalInit.call(this, enhancedConfig);
            }
        };

        // 对于v10+版本，使用新的API
        if (window.mermaid.run) {
            const originalRun = window.mermaid.run;
            window.mermaid.run = async function(options) {
                // 确保配置已应用
                if (!window.mermaidConfigured) {
                    window.mermaid.initialize({
                        startOnLoad: false,
                        securityLevel: 'loose'
                    });
                    window.mermaidConfigured = true;
                }
                return originalRun.call(this, options);
            };
        }

        // 兼容旧版本的init方法
        if (window.mermaid.init) {
            const originalInitMethod = window.mermaid.init;
            window.mermaid.init = function() {
                // 确保使用新配置
                if (!window.mermaidConfigured) {
                    window.mermaid.initialize({
                        startOnLoad: false,
                        securityLevel: 'loose'
                    });
                    window.mermaidConfigured = true;
                }
                return originalInitMethod.apply(this, arguments);
            };
        }
    }

    // 为新版本添加自定义CSS
    const style = document.createElement('style');
    style.textContent = `
        /* Mermaid中文和Emoji支持样式 */
        .mermaid {
            font-family: system-ui, -apple-system, "微软雅黑", "Microsoft YaHei", "Segoe UI", Roboto, "Helvetica Neue", "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji" !important;
        }

        .mermaid text {
            font-family: inherit !important;
            fill: #333;
        }

        .mermaid .nodeLabel,
        .mermaid .edgeLabel,
        .mermaid .cluster-label {
            font-family: inherit !important;
            line-height: 1.5;
        }

        /* 确保emoji正确显示 */
        .mermaid span {
            font-family: inherit !important;
        }

        /* 流程图节点样式 */
        .mermaid .node rect,
        .mermaid .node circle,
        .mermaid .node polygon {
            fill: #f9f9f9;
            stroke: #333;
            stroke-width: 1.5px;
        }

        .mermaid .node.clickable {
            cursor: pointer;
        }

        .mermaid .edgePath .path {
            stroke: #333;
            stroke-width: 1.5px;
        }

        /* 序列图样式 */
        .mermaid .actor {
            fill: #f9f9f9;
            stroke: #333;
            stroke-width: 1.5px;
        }

        .mermaid .actor-line {
            stroke: #333;
            stroke-width: 1px;
        }

        .mermaid .messageLine0,
        .mermaid .messageLine1 {
            stroke: #333;
            stroke-width: 1.5px;
        }

        /* 甘特图样式 */
        .mermaid .grid .tick {
            stroke: lightgrey;
            opacity: 0.3;
        }

        .mermaid .grid path {
            stroke-width: 0;
        }
    `;
    document.head.appendChild(style);

    console.log('Mermaid patch v10.9.0 loaded - Chinese and Emoji support enabled');
})();