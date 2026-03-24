library(tidyverse)

# 1. 设置颜色常量
COLOR_INITIAL <- "#CD5C5C" 
COLOR_RECURRENT <- "#6495ED" 
COLOR_ALL <- "#A9A9A9" 
COLOR_DARK_GREEN <- "#006400" 
COLOR_ORANGE <- "#FFA500" 


# 2. 读取数据
data <- read_csv("pure_data.csv")

# 3. 数据清洗和分组
data <- data %>%
  rename_with(str_trim) %>%
  mutate(
    # 转换为数值类型
    Visual_Acuity_Change = as.numeric(Visual_Acuity_Change),
    Age = as.numeric(Age),
    sEV_Protein_Change = as.numeric(sEV_Protein_Change),
    
    # 颜色分组: 设置 RVO_Eye 因子顺序 (OD, OS)
    RVO_Eye = factor(RVO_Eye, levels = c("OD", "OS")),
    
    # 根据 sEV_Protein_Change 分组为 Small, Medium, Large
    sEV_Protein_Change_Group = case_when(
      sEV_Protein_Change < 0.6 ~ "Small (0.6)",
      sEV_Protein_Change >= 0.6 & sEV_Protein_Change < 0.9 ~ "Medium (0.9)",
      sEV_Protein_Change >= 0.9 ~ "Large (1.2)",
      TRUE ~ "NA/Other"
    ),
    
    # 将新的分组变量转换为因子，并设置逻辑顺序
    sEV_Protein_Change_Group = factor(
      sEV_Protein_Change_Group,
      levels = c("Small (0.6)", "Medium (0.9)", "Large (1.2)", "NA/Other")
    ),
    
    # 设置 Type 因子顺序，确保 'All' 在最底层, 'Initial' 在最上层 ***
    Type = factor(Type, levels = c("All", "recurrent", "initial"))
  ) %>%
  # 移除关键 NA 行
  drop_na(Age, Visual_Acuity_Change, sEV_Protein_Change_Group, Type)


# 4. 趋势线数据准备：重新构建数据以支持波浪图
data_complete <- bind_rows(
  data %>% filter(Type == "recurrent") %>% mutate(Type = "recurrent"),
  data %>% filter(Type == "initial") %>% mutate(Type = "initial")
)
age_range <- seq(min(data_complete$Age), max(data_complete$Age), length.out = 100)
age_predict_df <- tibble(Age = age_range)

# 4.4. 手动拟合和预测 'Recurrent' 和 'Initial onset' 的趋势线数据
loess_recurrent <- loess(Visual_Acuity_Change ~ Age, data = data_complete %>% filter(Type == "recurrent"), span = 0.8)
loess_initial <- loess(Visual_Acuity_Change ~ Age, data = data_complete %>% filter(Type == "initial"), span = 0.8)

# 预测 Recurrent
data_recurrent_smooth <- age_predict_df %>%
  mutate(
    Visual_Acuity_Change = predict(loess_recurrent, newdata = .),
    Type = "recurrent"
  ) %>%
  drop_na(Visual_Acuity_Change)

# 预测 Initial
data_initial_smooth <- age_predict_df %>%
  mutate(
    Visual_Acuity_Change = predict(loess_initial, newdata = .),
    Type = "initial"
  ) %>%
  drop_na(Visual_Acuity_Change)


# 4.5. 计算 data_all_smooth 和 data_for_area 的堆叠逻辑
data_temp_wide <- full_join(
  data_recurrent_smooth %>% select(Age, Recurrent = Visual_Acuity_Change),
  data_initial_smooth %>% select(Age, Initial = Visual_Acuity_Change),
  by = "Age"
) %>% drop_na()

data_all_calculated <- data_temp_wide %>%
  mutate(
    Visual_Acuity_Change = Recurrent + Initial, # All = Recurrent + Initial
    Type = "All"
  ) %>%
  select(Age, Visual_Acuity_Change, Type)

data_for_area <- bind_rows(
  data_all_calculated,
  data_recurrent_smooth,
  data_initial_smooth
) %>%
  # 统一标签，设置因子顺序
  mutate(
    Type = case_when(
      Type == "recurrent" ~ "Recurrent",
      Type == "initial" ~ "Initial onset",
      TRUE ~ Type
    ),
    Type = factor(Type, levels = c("All", "Recurrent", "Initial onset"))
  )

# 5. 构建图例标签和颜色 

# 1: 散点颜色映射 (RVO_Eye) 
color_mapping_points <- c("OS" = COLOR_ORANGE, "OD" = COLOR_DARK_GREEN) 
fill_mapping_area <- c(
  "All" = COLOR_ALL,
  "Recurrent" = COLOR_RECURRENT,
  "Initial onset" = COLOR_INITIAL
)

# 散点图例百分比计算
total_count <- nrow(data)
eye_counts <- data %>% count(RVO_Eye) %>%
  mutate(percent = round((n / total_count) * 100, 1))

od_percent <- eye_counts %>% filter(RVO_Eye == "OD") %>% pull(percent)
os_percent <- eye_counts %>% filter(RVO_Eye == "OS") %>% pull(percent)


# 6. 绘制散点图并叠加波浪图
ggplot(data, aes(x = Age, y = Visual_Acuity_Change)) +
  
  # 1. 绘制波浪图 
  # 1.1 绘制 'All'
  geom_ribbon(
    data = data_for_area %>% filter(Type == "All"),
    aes(ymin = 0, ymax = Visual_Acuity_Change, fill = Type),
    alpha = 1.0
  ) +
  
  # 1.2 绘制 'Recurrent' 
  geom_ribbon(
    data = data_for_area %>% filter(Type == "Recurrent"),
    aes(ymin = 0, ymax = Visual_Acuity_Change, fill = Type),
    alpha = 0.7
  ) +
  
  # 1.3 绘制 'Initial onset' 
  geom_ribbon(
    data = data_for_area %>% filter(Type == "Initial onset"),
    aes(ymin = 0, ymax = Visual_Acuity_Change, fill = Type),
    alpha = 0.7
  ) +
  
  # 2. 绘制散点图
  geom_point(aes(color = RVO_Eye, size = sEV_Protein_Change_Group),
             alpha = 1.0) +
  
  # 4. 调整百分比标签位置和颜色
  annotate("text", x = min(data_complete$Age), y = 1.15, 
           label = paste0("OD ", od_percent, "%"), 
           color = COLOR_DARK_GREEN, size = 3.0, hjust = 0) + 
  
  annotate("text", x = min(data_complete$Age), y = 1.10, 
           label = paste0("OS ", os_percent, "%"), 
           color = COLOR_ORANGE, size = 3.0, hjust = 0) + 
  
  # 5. 设置图表标签和轴范围
  labs(
    x = "Age",
    y = "Visual acuity change(a.u.)",
    size = "sEV Protein Change"
  ) +
  
  #  6.  设置Y轴上限,步长
  scale_y_continuous(limits = c(0, 1.2), 
                     breaks = seq(0, 1.2, 0.2), 
                     expand = c(0, 0)) +
  
  scale_x_continuous(breaks = seq(40, 80, 10)) +
  
  # 7. 设置颜色和大小映射 
  scale_fill_manual(
    values = fill_mapping_area,
    labels = c("All", "Recurrent", "Initial onset"),
    name = NULL,
    guide = guide_legend(order = 2)
  ) +
  # : 设置散点颜色映射
  scale_color_manual(
    values = color_mapping_points,
    guide = "none" 
  ) +
  scale_size_manual(
    values = c("Small (0.6)" = 3.0,
               "Medium (0.9)" = 4.5, 
               "Large (1.2)" = 6.0, "NA/Other" = 1),
    drop = TRUE,
    guide = guide_legend(override.aes = list(color = "gray"))
  ) +
  
  # 8. 设置主题
  theme_classic() +
  theme(
    axis.line.x = element_line(color = "black"),
    axis.line.y = element_line(color = "black"),
    legend.position = "right",
    legend.box = "vertical",
    legend.justification = "left",
    legend.key = element_rect(fill = "transparent", color = NA),
    plot.margin = margin(10, 20, 10, 10)
  )