library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)

## ============================================================
## 堆积柱状图 + 真实桑基流向带
## ============================================================

input_prefix <- "复发_"  # 或 "初发_"
if(exists("EXTERNAL_PREFIX")) {
  input_prefix <- EXTERNAL_PREFIX
}

# 1. 读取数据
# ----------------------------------------
flow_with_selfloop <- read_csv(paste0(input_prefix, "flow_with_selfloop.csv"), show_col_types = FALSE)
flow_sankey <- read_csv(paste0(input_prefix, "sankey_flow.csv"), show_col_types = FALSE)

cat("读取到", nrow(flow_with_selfloop), "条流向数据（含自环）\n")
cat("读取到", nrow(flow_sankey), "条真实流向数据（不含自环）\n")

# 2. 提取样本顺序
# ----------------------------------------
# 按数字大小排序，而不是字符串排序
all_samples <- unique(sub("_(intersection|signal_only|not_signal)$", "", flow_with_selfloop$from))
all_samples <- all_samples[order(as.numeric(gsub("^X", "", all_samples)))]  # 按数字排序 (去掉X前缀)
cat("样本顺序:", paste(all_samples, collapse = " → "), "\n")

# 3. 准备堆积柱数据（百分比）
# ----------------------------------------
stacked_data <- flow_with_selfloop %>%
  filter(from == to) %>%
  mutate(
    sample = sub("_(intersection|signal_only|not_signal)$", "", from),
    class = sub(".*_(intersection|signal_only|not_signal)$", "\\1", from)
  ) %>%
  group_by(sample) %>%
  mutate(
    total = sum(weight),
    percentage = weight / total * 100
  ) %>%
  ungroup() %>%
  mutate(
    class = factor(class,
                   levels = c("intersection", "signal_only", "not_signal"),  
                   labels = c("Intersection", "Signal Only", "Not Signal")),
    sample = factor(sample, levels = all_samples),
    # 添加数值型x坐标用于绘图
    x = as.numeric(sample)
  ) %>%
  select(sample, x, class, count = weight, percentage)

cat("堆积数据准备完成:", nrow(stacked_data), "个节点\n")

# 4. 计算每个节点在堆积柱中的Y坐标范围
# ----------------------------------------
node_positions <- stacked_data %>%
  arrange(sample, class) %>%
  group_by(sample) %>%
  mutate(
    y_start = pmax(0, 100 - cumsum(percentage)),  # 确保不小于0
    y_end = lag(y_start, default = 100),
    y_center = (y_start + y_end) / 2
  ) %>%
  ungroup() %>%
  mutate(
    # 使用原始小写类别名构建node_id，以便与flow数据匹配
    class_lower = tolower(gsub(" ", "_", as.character(class))),
    node_id = paste0(as.character(sample), "_", class_lower),
    # X坐标：sample是factor，as.numeric会返回levels的索引位置（1,2,3...）
    x = as.numeric(sample)
  )

cat("节点位置计算完成:", nrow(node_positions), "个节点\n")

# 5. 为每条流向分配Y坐标
# ----------------------------------------
# 处理流向数据（不过滤，保留所有流向）
flow_processed <- flow_sankey %>%
  mutate(
    from_sample = sub("_(intersection|signal_only|not_signal)$", "", from),
    from_class_raw = sub(".*_(intersection|signal_only|not_signal)$", "\\1", from),
    to_sample = sub("_(intersection|signal_only|not_signal)$", "", to),
    to_class_raw = sub(".*_(intersection|signal_only|not_signal)$", "\\1", to)
  ) %>%
  mutate(
    from_class = factor(from_class_raw,
                       levels = c("intersection", "signal_only", "not_signal"),
                       labels = c("Intersection", "Signal Only", "Not Signal")),
    to_class = factor(to_class_raw,
                     levels = c("intersection", "signal_only", "not_signal"),
                     labels = c("Intersection", "Signal Only", "Not Signal")),
    # 使用原始小写格式构建node_id，与node_positions匹配
    from_node_id = paste0(from_sample, "_", from_class_raw),
    to_node_id = paste0(to_sample, "_", to_class_raw)
  )

# 计算每个from节点内的流向分配
# 添加边界间隙，确保所有流向都有明显宽度
gap_percent <- 0.5  # 在节点顶部和底部各留0.5%间隙

flow_with_y <- flow_processed %>%
  # 在起点节点内分配Y坐标
  group_by(from_node_id) %>%
  arrange(from_node_id, to_class, to_sample) %>%
  mutate(
    # 该流向在起点节点内的占比
    node_total = sum(weight),
    cumulative_in_node = cumsum(weight) / node_total * 100,
    start_in_node = lag(cumulative_in_node, default = 0)
  ) %>%
  ungroup() %>%
  # 关联起点Y坐标范围
  left_join(node_positions %>% select(node_id, x, y_start, y_end), 
            by = c("from_node_id" = "node_id")) %>%
  rename(x_from = x, from_y_total_start = y_start, from_y_total_end = y_end) %>%
  mutate(
    # 添加间隙让边界流向有明显宽度
    # 将100%的范围压缩到 (gap_percent, 100-gap_percent)
    effective_range = from_y_total_end - from_y_total_start,
    usable_range = effective_range * (100 - 2*gap_percent) / 100,
    from_y_start = from_y_total_end - gap_percent/100 * effective_range - usable_range * cumulative_in_node / 100,
    from_y_end = from_y_total_end - gap_percent/100 * effective_range - usable_range * start_in_node / 100
  ) %>%
  # 在终点节点内分配Y坐标
  group_by(to_node_id) %>%
  arrange(to_node_id, from_class, from_sample) %>%
  mutate(
    # 该流向在终点节点内的占比
    to_node_total = sum(weight),
    to_cumulative_in_node = cumsum(weight) / to_node_total * 100,
    to_start_in_node = lag(to_cumulative_in_node, default = 0)
  ) %>%
  ungroup() %>%
  # 关联终点Y坐标范围
  left_join(node_positions %>% select(node_id, x, y_start, y_end), 
            by = c("to_node_id" = "node_id"), suffix = c("", "_to")) %>%
  rename(x_to = x, to_y_total_start = y_start, to_y_total_end = y_end) %>%
  mutate(
    # 从节点顶部往下累加，添加间隙让边界流向有明显宽度
    to_effective_range = to_y_total_end - to_y_total_start,
    to_usable_range = to_effective_range * (100 - 2*gap_percent) / 100,
    to_y_start = to_y_total_end - gap_percent/100 * to_effective_range - to_usable_range * to_cumulative_in_node / 100,
    to_y_end = to_y_total_end - gap_percent/100 * to_effective_range - to_usable_range * to_start_in_node / 100
  )

cat("流向Y坐标计算完成:", nrow(flow_with_y), "条流向\n")

# 6. 生成贝塞尔曲线流向带
# ----------------------------------------
generate_bezier_ribbon <- function(x1, y1_bottom, y1_top, x2, y2_bottom, y2_top, n_points = 50) {
  # 生成平滑的S形曲线（三次贝塞尔）
  t <- seq(0, 1, length.out = n_points)
  
  # 控制点位置（决定曲线形状）
  cx1 <- x1 + (x2 - x1) * 0.5
  cx2 <- x1 + (x2 - x1) * 0.5
  
  # 三次贝塞尔曲线公式
  bezier_x <- (1-t)^3 * x1 + 3*(1-t)^2*t * cx1 + 3*(1-t)*t^2 * cx2 + t^3 * x2
  
  # 上边界Y坐标
  bezier_y_top <- (1-t)^3 * y1_top + 3*(1-t)^2*t * y1_top + 
                  3*(1-t)*t^2 * y2_top + t^3 * y2_top
  
  # 下边界Y坐标
  bezier_y_bottom <- (1-t)^3 * y1_bottom + 3*(1-t)^2*t * y1_bottom + 
                     3*(1-t)*t^2 * y2_bottom + t^3 * y2_bottom

  data.frame(
    x = c(bezier_x, rev(bezier_x)),
    y = c(bezier_y_top, rev(bezier_y_bottom))
  )
}

# 为每条流向生成多边形数据，并创建组合标识
flow_ribbons <- flow_with_y %>%
  rowwise() %>%
  mutate(
    ribbon_data = list(generate_bezier_ribbon(
      x_from, from_y_start, from_y_end,
      x_to, to_y_start, to_y_end,
      n_points = 50
    ))
  ) %>%
  ungroup() %>%
  mutate(
    flow_id = row_number(),
    # 创建from-to类别组合标识（用于着色）
    flow_type = paste0(from_class, " → ", to_class)
  ) %>%
  select(flow_id, from_class, to_class, flow_type, ribbon_data) %>%
  unnest(ribbon_data)

cat("流向Ribbon数据生成完成:", nrow(flow_ribbons), "个点 (", 
    length(unique(flow_ribbons$flow_id)), "条流向)\n")

# 7. 为不同流向类型分配颜色
# ----------------------------------------
# 基础颜色（按源类别）
base_colors_flow <- c(
  "Intersection" = "#01359C",  # 深蓝
  "Signal Only" = "#7ECFFB",   # 浅蓝
  "Not Signal" = "#F5B0AB"     # 浅粉
)

# 为每种流向类型（from_class → to_class）生成颜色变体
library(colorspace)
unique_flow_types <- unique(flow_ribbons$flow_type)

flow_colors <- setNames(
  character(length(unique_flow_types)),
  unique_flow_types
)

for (ftype in unique_flow_types) {
  parts <- strsplit(ftype, " → ")[[1]]
  from_cls <- parts[1]
  to_cls <- parts[2]
  
  base_color <- base_colors_flow[from_cls]
  
  # 根据目标类别调整色相/饱和度
  hcl_color <- as(hex2RGB(base_color), "polarLUV")
  
  if (to_cls == from_cls) {
    hcl_color@coords[1, "L"] <- hcl_color@coords[1, "L"] * 0.9
  } else if (to_cls == "Intersection") {
    # 流向Intersection：加深
    hcl_color@coords[1, "L"] <- hcl_color@coords[1, "L"] * 0.7
  } else if (to_cls == "Signal Only") {
    # 流向Signal Only：稍微调亮
    hcl_color@coords[1, "L"] <- min(95, hcl_color@coords[1, "L"] * 1.1)
  } else if (to_cls == "Not Signal") {
    # 流向Not Signal：明显调亮
    hcl_color@coords[1, "L"] <- min(95, hcl_color@coords[1, "L"] * 1.3)
  }
  
  flow_colors[ftype] <- hex(hcl_color)
}

cat("生成", length(flow_colors), "种流向类型的颜色\n")

# 8. 绘制完整桑基图
# ----------------------------------------

# 确定标题内容
title_fc <- if(grepl("FC1\\.5", input_prefix)) "FC||1.5" else "FC||2"
title_group <- if(grepl("初发", input_prefix)) "Initial Group" else "Recurrent Group"
plot_title <- paste(title_fc, title_group)

# 处理X轴标签（去掉X前缀）
x_labels_clean <- gsub("^X", "", all_samples)

p_flow <- ggplot() +
  # 底层：堆积柱（使用矩形，指定准确的Y坐标范围）
  geom_rect(data = node_positions,
            aes(xmin = x - 0.15, xmax = x + 0.15, 
                ymin = y_start, ymax = y_end, fill = class),
            color = "white", linewidth = 0.8, alpha = 0.9) +
  # 前景层：流向带（更透明，不遮挡柱子）
  geom_polygon(data = flow_ribbons,
               aes(x = x, y = y, group = flow_id, fill = from_class),
               alpha = 0.3, color = "white", linewidth = 0.1) +
  scale_fill_manual(
    name = "Protein Type",
    values = c(base_colors_flow, flow_colors),
    breaks = names(base_colors_flow),
    labels = names(base_colors_flow)
  ) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, 100),
                     breaks = seq(0, 100, 25)) +
  scale_x_continuous(
    breaks = 1:length(all_samples),  # X轴刻度位置：1, 2, 3...
    labels = x_labels_clean,         # X轴标签：去前缀后的样本ID
    expand = c(0.05, 0.05)           # 左右留白
  ) +
  labs(x = "Sample",
       y = "Percentage of Proteins (%)",
       title = plot_title) +
  theme_classic(base_size = 13) +
  theme(
    axis.text.x = element_text(size = 11, face = "bold"),
    axis.text.y = element_text(size = 10),
    axis.title.y = element_text(size = 12, face = "bold"),
    axis.title.x = element_text(size = 12, face = "bold"),
    legend.position = "right",
    legend.title = element_text(size = 11, face = "bold"),
    legend.text = element_text(size = 10),
    plot.title = element_text(size = 14, face = "bold", hjust = 0.5),
    plot.caption = element_text(size = 9, hjust = 0.5, color = "gray40"),
    panel.grid.major.y = element_line(color = "gray90", linewidth = 0.3),
    plot.margin = margin(10, 10, 10, 10)
  )

# print(p_flow) # Removed to prevent Rplots.pdf generation in batch mode

# 9. 保存图片
# ----------------------------------------
if(exists("EXTERNAL_OUTPUT_DIR_PLOGS")) {
  # Use separate Plogs directory if provided
  base_name <- basename(input_prefix)
  output_prefix <- file.path(EXTERNAL_OUTPUT_DIR_PLOGS, paste0(base_name, "桑基流向图"))
} else {
  # Default: same directory as input
  output_prefix <- paste0(input_prefix, "桑基流向图")
}

ggsave(paste0(output_prefix, ".png"), p_flow,
       width = 20, height = 8, dpi = 300, bg = "white")

ggsave(paste0(output_prefix, ".pdf"), p_flow,
       width = 20, height = 8, bg = "white")

cat("✓ 已保存桑基流向图:", paste0(output_prefix, ".png/pdf\n"))

## ============================================================
## 输出说明
## ============================================================

cat("\n========== 完成 ==========\n")
cat("✓ 已生成桑基流向图\n")
cat("\n输入文件:\n")
cat(sprintf("- %sflow_with_selfloop.csv (自环数据用于堆积柱)\n", input_prefix))
cat(sprintf("- %ssankey_flow.csv (真实流向数据)\n", input_prefix))
cat("\n输出文件:\n")
cat(sprintf("- %s桑基流向图.png (300 DPI)\n", input_prefix))
cat(sprintf("- %s桑基流向图.pdf (矢量图)\n", input_prefix))
cat("========================\n")
