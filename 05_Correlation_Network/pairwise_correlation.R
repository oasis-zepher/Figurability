# 使用 GGally::ggpairs 绘制可定制配色的相关性配对矩阵图
# 需求实现：
# 1) 对角线：核密度图
# 2) 下三角：散点 + 线性回归拟合线
# 3) 上三角：Pearson 相关系数 + 按相关强度着色背景

ensure_packages <- function(pkgs) {
  missing_pkgs <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_pkgs) > 0) {
    install.packages(missing_pkgs, repos = "https://cloud.r-project.org")
  }
}

ensure_packages(c("GGally", "ggplot2", "scales"))

library(GGally)
library(ggplot2)
library(scales)

# 可修改的配色接口：tone 支持 blue / green / purple
make_tone_colors <- function(tone = c("blue", "green", "purple")) {
  tone <- match.arg(tone)
  palettes <- list(
    blue = list(low = "#eff3ff", mid = "#6baed6", high = "#08519c", point = "#2171b5", line = "#08306b", diag_fill = "#9ecae1"),
    green = list(low = "#edf8e9", mid = "#74c476", high = "#006d2c", point = "#31a354", line = "#00441b", diag_fill = "#a1d99b"),
    purple = list(low = "#f2f0f7", mid = "#9e9ac8", high = "#54278f", point = "#756bb1", line = "#3f007d", diag_fill = "#bcbddc")
  )
  palettes[[tone]]
}

build_pair_plot <- function(df, tone = c("blue", "green", "purple")) {
  tone <- match.arg(tone)
  cols <- make_tone_colors(tone)
  cor_fill <- scales::col_numeric(
    palette = c(cols$low, cols$mid, cols$high),
    domain = c(-1, 1)
  )

  # 上三角：相关系数 + 背景颜色
  upper_cor_panel <- function(data, mapping, ...) {
    x <- GGally::eval_data_col(data, mapping$x)
    y <- GGally::eval_data_col(data, mapping$y)
    r <- suppressWarnings(cor(x, y, method = "pearson", use = "pairwise.complete.obs"))

    if (is.na(r)) {
      r <- 0
      label_text <- "NA"
    } else {
      label_text <- sprintf("%.2f", r)
    }

    ggplot() +
      geom_rect(
        aes(xmin = 0, xmax = 1, ymin = 0, ymax = 1),
        fill = cor_fill(r),
        color = NA
      ) +
      annotate(
        "text",
        x = 0.5,
        y = 0.5,
        label = label_text,
        size = 5,
        fontface = "bold",
        color = ifelse(abs(r) >= 0.6, "white", "black")
      ) +
      coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
      theme_void()
  }

  # 下三角：散点 + 线性回归拟合线
  lower_scatter_lm_panel <- function(data, mapping, ...) {
    ggplot(data = data, mapping = mapping) +
      geom_point(color = cols$point, alpha = 0.7, size = 1.6) +
      geom_smooth(method = "lm", se = FALSE, color = cols$line, linewidth = 0.8)
  }

  GGally::ggpairs(
    df,
    diag = list(
      continuous = GGally::wrap(
        "densityDiag",
        fill = cols$diag_fill,
        alpha = 0.7,
        color = cols$high
      )
    ),
    lower = list(continuous = lower_scatter_lm_panel),
    upper = list(continuous = upper_cor_panel),
    progress = FALSE
  ) +
    theme_bw(base_size = 12) +
    theme(
      panel.grid = element_blank(),
      strip.background = element_rect(fill = "white", color = "grey70")
    )
}

generate_pair_plot_variants <- function(
  df,
  output_dir,
  tones = c("blue", "green", "purple"),
  prefix = "pair_plot_iris"
) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  out_files <- character(0)

  for (tone in tones) {
    p <- build_pair_plot(df, tone = tone)
    out_file <- file.path(output_dir, sprintf("%s_%s.png", prefix, tone))
    ggsave(out_file, p, width = 11, height = 11, dpi = 300)
    out_files <- c(out_files, out_file)
  }

  out_files
}

# 示例数据：使用 iris 数值列，开箱即用
demo_df <- iris[, 1:4]

# 脚本和图像都放在当前脚本所在目录
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) > 0) {
  script_path <- sub("^--file=", "", script_arg[1])
  output_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE))
} else {
  # 在交互式环境中回退到当前工作目录
  output_dir <- getwd()
}

files <- generate_pair_plot_variants(
  df = demo_df,
  output_dir = output_dir,
  tones = c("blue", "green", "purple"),
  prefix = "pair_plot_ggpairs_demo"
)

cat("已生成图片:\n")
cat(paste0("- ", files, collapse = "\n"), "\n")
