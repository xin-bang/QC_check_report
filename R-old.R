#本流程目前仅适用于T2P2;T3P2；T11的流程质控分析；
#其中回顾性统计仅针对T2P2;T3P2;回顾性绘图中也仅针对DJ，LY标准
#编辑：20240501

#! /usr/bin/env Rscript
rm(list=ls())
suppressPackageStartupMessages({
  library(argparse)
  library(ggplot2)
  library(readxl)
  library(stringr)
  library(tidyverse)
  library(dplyr)
  library(writexl)
  library(openxlsx)
  library(extrafont)
  library(gridExtra)
  library(ggpubr)
  library(stringi)
  # library(patchwork)
})

# #定义调试参数，还未找到很好的解决办法
# # 202405111修订：增加核对功能： 质检表里的文库名在SampleSheet中是否存在
# args <- list(
#   input_run = ".",
#   input0 = "./00_raw_data/Patho_report_final_format.addt5.project.sort.zip",
#   input1 = "./00_raw_data/QC_report_for_experiment.addt5.xls.zip",
#   input2 = "./00_raw_data/all_HP_vardect.txt.zip",
#   input3 = "./00_raw_data/Patho_report_final_format.trim.rptname.ntinfo.addsemi.zip",
#   input4 = "./00_raw_data/all.drug_mp.txt",
#   input5 = "./00_raw_data/240705_TPMN00173_0337_A000H7FW5J-历史质检表.xlsx",
#   output1 = "./Test_QC_result.xlsx",
#   input6 = "./current_history_results.xlsx",
#   input7 = "./00_raw_data/config.xlsx",
#   input8 = "./00_raw_data/SampleSheetUsed.csv",
#   date = "240705",
#   output2 = "./current_history_results_thistime.xlsx",
#   comparepdf = "Test_QC_compare.pdf",
#   Retropdf = "Test_QC_retro.pdf"
# )






# #参数定义：
parser <- ArgumentParser(description="用于质控信息数据分析，目前仅针对T2P2、T3P3、T3P2以及T11中的企参和临床样本；其余类型样本无法分析")
parser$add_argument("--input_run", help="输入待分析run的path")
parser$add_argument("--input0", help="输入Patho_report_final_format.addt5.project.sort.zip")
parser$add_argument("--input1", help="输入QC_report_for_experiment.addt5.xls.zip")
parser$add_argument("--input2", help="输入all_HP_vardect.txt.zip")
parser$add_argument("--input3", help="输入Patho_report_final_format.trim.rptname.ntinfo.addsemi.zip")
parser$add_argument("--input4", help="输入all.drug_mp.txt")
parser$add_argument("--input5", help="输入质检软件SampleSheet模板表,注意需要核对样本名是否规范！！！")
parser$add_argument("--output1", help="质控信息分析结果表名称")
parser$add_argument("--input6", help="输入回顾性信息表")
parser$add_argument("--input7", help="输入配置文件")
parser$add_argument("--input8",help = "输入SampleSheetUsed.csv文件")
parser$add_argument("--date", nargs='?', type="character", help="回顾性中指定日期，格式如240306")
parser$add_argument("--output2", help="纳入本轮质控分析结果的回顾性表名称")
parser$add_argument("--comparepdf", help="输出对比分析的pdf,仅在Compare为True起作用")
parser$add_argument("--Retropdf", help="输出回顾性分析的pdf,仅在Rstro为True起作用")
args <- parser$parse_args()     # 解析参数





###################################
# 定义要解压的文件和目标文件夹
zip_file0 <- args$input0
zip_file1 <- args$input1
zip_file2 <- args$input2
zip_file3 <- args$input3
zip_file4 <- args$input4


#########################################################################
# 定义函数用于检查和删除文件或文件夹
check_and_delete <- function(path) {
  if (file.exists(path)) {
    if (file.info(path)$isdir) {
      unlink(path, recursive = TRUE)
      print(paste("文件夹", path, "及其内容已被删除。"))
    } else {
      file.remove(path)
      print(paste("文件", path, "已被删除。"))
    }
  } else {
    print(paste("文件或文件夹", path, "不存在。"))
  }
}

# 检查并删除文件夹
output_dir <- paste0(args$input_run,"/01_supplement_info_unzip")
check_and_delete(output_dir)

# 检查并删除文件
check_and_delete(paste0(args$input_run, "/02.Macro/05.QA/succeed.log"))
check_and_delete(paste0(args$input_run, "/02.Macro/05.QA/error.log"))
#############################################################################

system_unzip <- function(zip_file, output_dir, password) {
  if (Sys.info()["sysname"] == "Linux") {
    command <- sprintf("unzip -P %s '%s' -d '%s'", password, zip_file, output_dir)  #linux 系统
  } else if (Sys.info()["sysname"] == "Windows") {
    command <- sprintf("wsl unzip -P %s '%s' -d '%s'", password, zip_file, output_dir)  #win 系统
  } else {
    stop("Unsupported operating system.")  # 如果是其他操作系统，抛出错误
  }
  system(command)
}

for (zip_file in list(zip_file0, zip_file1, zip_file2, zip_file3, zip_file4)) {
  file_name <- basename(zip_file)
  extension <- tools::file_ext(file_name)
  if (extension %in% c("zip")) {
    system_unzip(zip_file, output_dir, "kctngs2023")
  } else {
    file.copy(zip_file, file.path(output_dir, file_name))
  }
}



df1 = read.table(paste0(output_dir,"/Patho_report_final_format.addt5.project.sort"),
                 sep = "\t", quote = "\"",header = TRUE,comment.char = "") %>% as_tibble() %>% 
  rename(RUN = run,实验号=sample,病原体= patho_namezn,检测reads数 = patho_reads,
         归一化reads数=patho_RPK,预判结果 = filter_flag) %>% 
  select(RUN,实验号,病原体,检测reads数,归一化reads数,预判结果) %>% distinct()

df2 = read.table(paste0(output_dir,"/QC_report_for_experiment.addt5.xls"),
                 sep = "\t", quote = "\"",header = TRUE,comment.char = "") %>% as_tibble() %>% 
  rename(实验号=sample,原始数据=raw_reads_num,Q30 = raw_Q30, 过滤后数据量=clean_reads_num,质控合格比例 = clean_reads_ratio,
         质控评价 = qc_status,有效数据量 = valid_reads_num,有效数据比例= valid_reads_ratio,有效病原数据量 =valid_micro_reads_num ) %>% 
  select(实验号,原始数据,Q30,过滤后数据量,质控合格比例,质控评价,有效数据量,有效数据比例,有效病原数据量)



##输入后台下机数据清洗整理
################################################################################
#合并：为df1添加样本信息
df1 <- df1 %>%
  full_join(df2, by = c("实验号" = "实验号"))

#根据run去添加date信息
df1 <- df1 %>%
  separate(RUN, into = c("date"), sep = "_",remove = FALSE)

#根据实验号去添加体系信息
df1$体系 <- sapply(
  lapply(strsplit(as.character(df1$实验号), "-"), trimws), 
  function(x) x[1])

#修改部分名称
df1 <- df1 %>%
  rename(sample = 实验号,run=RUN,patho_namezn = 病原体,patho_reads =有效病原数据量,
         patho_RPK = 归一化reads数,filter_flag = 预判结果)
################################################################################






##编号添加 和 将企参数据整合至下机数据中
################################################################################
#添加temp_id 以添加企参组成信息：temp_id为第二个"-"分隔符前的元素：T11A-L01-1-DJ 则temp_id为T11A-L01
df1$temp_id  = sapply(strsplit(df1$sample, "-"), function(x) {
  if (length(x) > 2) {
    paste(x[1:2], collapse = "-")
  } else {
    paste(x, collapse = "-")
  }
})


df3 = read.xlsx(args$input5,sheet = "表1-基本信息表")  ##需要核对名称是否正确
colnames(df3) <- df3[1, ]
df3 <- df3[-1, ] %>% filter(!is.na(文库类型)) %>% filter(!is.na(文库编号))


##20240511修订：增加核对功能： 质检表里的文库名在SampleSheet中是否存在
###########################
sample_sheet = readLines(args$input8)
skip_line = grep("^\\[Data\\]", sample_sheet, value = FALSE)[1]
df_samplesheet = read.csv(args$input8,header = TRUE,skip= skip_line)

# 检查 df3$文库编号 和 df_samplesheet$Sample_ID 是否一致
consistency <- setequal(df3$文库编号, df_samplesheet$Sample_ID)
unconsistency_A = setdiff(df3$文库编号, df_samplesheet$Sample_ID)
unconsistency_B = setdiff(df_samplesheet$Sample_ID, df3$文库编号)  
messages_df <- data.frame(Message = character())
if (consistency) {
  messages_df <- rbind(messages_df, data.frame(Message = "Samplesheet样本和质控样本一致"))
} else {
  messages_df <- rbind(messages_df, data.frame(Message = paste("质检表较SampleSheet多出的样本：",paste(unconsistency_A,collapse = ","))))
  messages_df <- rbind(messages_df, data.frame(Message = paste("SampleSheet较质检表多出的样本：",paste(unconsistency_B, collapse = ","))))
}
###########################



##添加一个核对的信息表格，列数不对则报错不予分析
check_columns <- function(df, columns) {
  missing_columns <- setdiff(columns, names(df))
  if (length(missing_columns) > 0) {
    stop(paste("数据框缺少以下列:", paste(missing_columns, collapse = ", ")))
  }
}
# 使用tryCatch()来捕获可能的错误
tryCatch({
  check_columns(df3, c("文库编号", "生产批号", "产品检类别","成品对应中间品批号",
                       "生产工艺","核酸提取日期","核酸重复次数","提取重复次数",
                       "文库浓度","Pooling体积","提取试剂规格","提取试剂批号",
                       "文库类型","企参编号"))
}, error = function(e) {
  print(paste("错误:", e$message))
})

df1 <- df1 %>%full_join(df3, by = c("sample" = "文库编号"))   ##有一些在project sort中会被过滤的
df1$体系 = str_split(df1$sample, "-", simplify = TRUE)[, 1]


#按照企参编号匹配型别（目标病原）
df3_add_patho = read.xlsx(args$input5,sheet = "企参列表") %>% select("编号","型别") %>% distinct()

#20240627修订，将企参编号为na的替换为空，避免由于之间模板表填写不规范而导致的错误。
df1 = df1 %>% mutate(企参编号 = case_when(
  is.na(企参编号) ~ "",
  TRUE ~ 企参编号
))
df1 <- df1 %>%left_join(df3_add_patho, by = c("企参编号" = "编号"),relationship = "many-to-many")
df1 = df1 %>% rename("tag_sample" = "文库类型","tag" = "temp_id") 
df1 = df1 %>% filter(tag_sample != "")
df1 = df1 %>% mutate(型别 = case_when(
  tag_sample == "其它" ~ NA,
  TRUE ~ 型别
))
df1 = df1 %>% distinct()


##########判断输入sample 名称是否规范
# 定义条件函数，检查列是否为空，同时处理NA值
is_empty <- function(x) {
  return(is.na(x) | x == "")
}

# 设置options，使警告被视为错误
options(warn=2)

# 修改check_condition函数，使其检查df1的tag_sample列是否为空或包含NA
check_condition <- function(df, column_name, condition_function) {
  # 检查列的元素是否满足条件
  if (any(condition_function(df[[column_name]]))) {
    # 如果满足条件（即列为空或包含NA），将不满足条件的df1$sample的值输出到error.log文件中
    sink(paste0(args$input_run,"/02.Macro/05.QA/error.log"), append = TRUE)
    write(df$sample[condition_function(df[[column_name]])], file = paste0(args$input_run,"/02.Macro/05.QA/error.log"), append = TRUE)
    print(paste("Warning：", "文库编号不规范，请修改名称"))
    sink()
    # 这里的警告会被转换为错误，导致程序停止执行
    warning("文库编号不规范，请修改名称")
    unlink(output_dir, recursive = TRUE)
  }
}

check_condition(df1, "tag_sample", is_empty)
options(warn=0)
##########

#选择相应的列
df4 = df1 %>% filter(!is.na(tag_sample))
df4 = lapply(df4,as.character) %>% as_tibble()
df4$patho_RPK = as.numeric(df4$patho_RPK)
################################################################################



##对整合企参信息之后的DF进行数据清洗
################################################################################
#清洗patho_name，定义新的patho_name2以规范病原体名称
#20240529：枯草和 三叶草 的名称问题修改；patho_namezn2 是原名称；patho_namezn是规范后的名称；后续的分析都是用规范后的名称：patho_namezn
df4$patho_namezn2 = df4$patho_namezn
patho_name_fix <- read.xlsx(args$input7,sheet = "patho_name_fix")

for (i in 1:nrow(patho_name_fix)) {
  df4 <- df4 %>%
    mutate(patho_namezn = case_when(
      grepl(patho_name_fix$Original_name[i], patho_namezn) ~ patho_name_fix$replacement[i],
      TRUE ~ patho_namezn
    ))
}

####个性化删减：
#1:删除型别为“百日咳鲍特菌”时的“霍姆鲍特菌”检出情况；删除百日咳的耐药结果
#NA代表缺失值，而在逻辑操作中，NA与任何值的比较结果都是NA,因而会被过滤掉
df4 = df4 %>% filter(!(型别 == "百日咳鲍特菌" & patho_namezn == "霍姆鲍特菌") | is.na(型别) | is.na(patho_namezn))
df4 = df4 %>% filter(!str_detect(patho_namezn, "百日咳耐药__ptxP") | is.na(patho_namezn))
################################################################################



##添加耐药信息:
################################################################################
#Sheet1:/02.Macro/03.HPVarDect/all_HP_vardect.txt.zip + 04.Drug_MP/all.drug_mp.txt
#Sheet2:/02.Macro/02.Statistic/Patho_report_final_format.trim.rptname.ntinfo.addsemi.zip   解压密码：kctngs2023
drug1 = read.table(paste0(output_dir,"/all.drug_mp.txt"), sep = "\t",  quote = "\"",header = TRUE, comment.char = "") %>% as_tibble()
drug2 = read.table(paste0(output_dir,"/all_HP_vardect.txt"), sep = "\t",  quote = "\"",header = TRUE, comment.char = "") %>% as_tibble()
all_patho = read.table(paste0(output_dir,"/Patho_report_final_format.trim.rptname.ntinfo.addsemi"),sep = "\t", quote = "\"",
                       header = TRUE,comment.char = "") %>% as_tibble()

##20240708修订：改变resis_rpk，resis_RawDep中class
drug1 = drug1 %>% mutate_at(vars(resis_RawDep,resis_rpk),as.numeric)
drug2 = drug2 %>% mutate_at(vars(resis_RawDep,resis_rpk),as.numeric)


if (nrow(drug1) == 0 && nrow(drug2) == 0) {
  df_drug1 <- drug1
} else if (nrow(drug1) == 0) {
  df_drug1 <- drug2  
} else if (nrow(drug2) == 0) {
  df_drug1 <- drug1 
} else {
  df_drug1 = full_join(drug1,drug2)
}


df_drug2 = all_patho
df_drug2 = all_patho %>% mutate(patho_namezn =case_when(
  grepl("百日咳",patho_namezn) & grepl("大环内酯耐药",patho_namezn) ~ "百日咳鲍特菌耐药",
  TRUE ~ patho_namezn
))


df_drug1 =df_drug1 %>% select(run,sample,resis_name,resis_MutLog,resis_rpk)
df_drug2$耐药名称 = sapply(
  lapply(strsplit(as.character(df_drug2$patho_namezn), "_"), trimws), 
  function(x) x[1])
df_drug2 =df_drug2 %>% select(run,sample,耐药名称,patho_RPK)
df_drug1 = df_drug1 %>% 
  left_join(df_drug2,by=c("sample" = "sample","resis_name" = "耐药名称")) 

#百日耐药：只从all_HP_vardect.txt.zip 提取RPK
df_drug1 =df_drug1 %>% filter(resis_rpk != "-")
df_drug1$resis_rpk = as.numeric(df_drug1$resis_rpk)
df_drug1 = df_drug1 %>% mutate(
  patho_RPK = case_when(
    resis_name == "百日咳鲍特菌耐药" ~ resis_rpk,
    TRUE ~ patho_RPK
  )
)




##对几列进行融合操作
df_drug1 = df_drug1 %>% filter(resis_MutLog != "不适用") %>% 
  unite("drug_info",resis_name,resis_MutLog,patho_RPK,sep ="|",remove = FALSE) %>% 
  select(-run.y,-run.x,-patho_RPK,-resis_rpk) %>% distinct()
df4 <- df4 %>%
  left_join(df_drug1, by = c("sample" = "sample"),relationship = "many-to-many")   
################################################################################






###企参样本分析
################################################################################
df5 = df4 %>% filter(!is.na(tag_sample))

##剔除部分重名的病原：后续也要单独核对，以防止重名病原遗漏。
df5 = df5 %>% 
  filter(!patho_namezn %in% c("肠道病毒","肠道病毒A组","人腺病毒E组","人腺病毒C组","人腺病毒21型","人腺病毒B组","人腺病毒")) 

##根据patho_namezn 将病原分类为：目标、外源、外源内参、人内参等args$input7
patho_class <- read.xlsx(args$input7,sheet = "patho_class") 
df5$patho_tag = "外源病原"    #默认都是外源内参，如果需要添加，请在配置文件中调整
for (i in 1:nrow(patho_class)) {
  df5 <- df5 %>%
    mutate(patho_tag = case_when(
      grepl(patho_class$condition[i], patho_namezn) & grepl(patho_class$tag[i], tag) ~ patho_class$label[i],
      grepl(patho_class$condition[i], patho_namezn) & grepl(patho_class$tag[i], 体系) ~ patho_class$label[i],
      TRUE ~ patho_tag
    ))
}


##生成统计表
df5_cc = df5
df5_cc$patho_tag2 =df5_cc$patho_tag  ##新定义patho_tag2用以将“外源病原”的信息整合在一起
df5_cc$patho_RPK = as.character(df5_cc$patho_RPK)
df5_cc<- df5_cc %>%
  mutate(patho_tag2 = case_when(
    grepl("外源病原", patho_tag) ~ paste0(patho_namezn, "|", filter_flag,"|",patho_RPK),
    TRUE ~ patho_RPK ##条件没有满足，则为原来的数字
  ))


##剔除部分重名的病原：后续也要单独核对，以防止重名病原遗漏。
df5_cc = df5_cc %>% 
  filter(!patho_namezn %in% c("肠道病毒","肠道病毒A组","人腺病毒E组","人腺病毒C组","人腺病毒21型","人腺病毒B组","人腺病毒")) 


df5_cc_temp = df5_cc %>%
  filter(patho_tag == "目标病原") %>%
  select(run,sample,型别,filter_flag,patho_namezn) %>% distinct()
df5_cc = df5_cc %>%
  select(run,date,sample,体系,tag,tag_sample,型别,原始数据,Q30,patho_tag,patho_tag2,resis_MutLog,drug_info,
         生产批号,产品检类别,成品对应中间品批号,生产工艺,核酸提取日期,核酸重复次数,提取重复次数,文库浓度,Pooling体积) %>%distinct()


##20240705:使用stop 终止 目标病原为空的情况，并抛出错误
if (length(df5_cc_temp) == 0) {
  stop(paste("目标病原记录为空，请检查实验号是否记录错误"))
}



df5_cc_stat = df5_cc %>%  pivot_wider(names_from = patho_tag, values_from = patho_tag2,values_fn = list)  
df5_cc_stat$外源病原 <- sapply(df5_cc_stat$外源病原, function(x) paste(x, collapse = ";"))
##规范耐药信息列
df5_cc_stat = df5_cc_stat %>% 
  mutate(drug_info = case_when(
    grepl("不适用",resis_MutLog) ~ " ",   #不适用的直接为空值，drug_info
    TRUE ~ drug_info
  ))

df5_cc_stat= df5_cc_stat %>% 
  left_join(df5_cc_temp, by = c("run" = "run","sample" = "sample", "型别" = "型别")) 



df5_cc_stat = df5_cc_stat %>% pivot_wider(names_from = resis_MutLog, values_from = drug_info,values_fn = list)  
##结果敏感和耐药交替出现的情况
if ("耐药" %in% names(df5_cc_stat) & "敏感" %in% names(df5_cc_stat)) {
  df5_cc_stat = df5_cc_stat %>% unite("resis_info",耐药,敏感,sep =";",remove = TRUE)
  df5_cc_stat$resis_info = gsub("NULL;","",df5_cc_stat$resis_info)
  df5_cc_stat$resis_info = gsub(";NULL","",df5_cc_stat$resis_info)
} else if ("耐药" %in% names(df5_cc_stat) & !("敏感" %in% names(df5_cc_stat))){
  df5_cc_stat = df5_cc_stat %>% rename(resis_info = 耐药)
} else if ("敏感" %in% names(df5_cc_stat) & !("耐药" %in% names(df5_cc_stat))){
  df5_cc_stat = df5_cc_stat %>% rename(resis_info = 敏感)
} else if (!("敏感" %in% names(df5_cc_stat)) & !("耐药" %in% names(df5_cc_stat))){
  df5_cc_stat = df5_cc_stat %>% rename(resis_info = "NA")
}

##个性化调整
df5_cc_stat =df5_cc_stat %>% rename("目标病原" = "型别","其它病原" = "外源病原","目标病原RPK" = "目标病原","目标病原预判" = "filter_flag") %>% 
  select(run,date,sample,体系,tag,tag_sample,原始数据,Q30,目标病原,目标病原RPK,目标病原预判,contains("内参"),其它病原,resis_info,patho_namezn,
         生产批号,产品检类别,成品对应中间品批号,生产工艺,核酸提取日期,核酸重复次数,提取重复次数,文库浓度,Pooling体积)


df5_cc_stat$目标病原 = gsub("枯草芽孢杆菌","阳性对照品",df5_cc_stat$目标病原)
df5_cc_stat$目标病原 = gsub("人副流感2型","人腮腺炎病毒2型（人副流感病毒2型）",df5_cc_stat$目标病原)
df5_cc_stat$目标病原 = gsub("Jurkat细胞沉淀","",df5_cc_stat$目标病原)
df5_cc_stat$目标病原 = gsub("无核酸酶水","",df5_cc_stat$目标病原)
df5_cc_stat$其它病原 = gsub("未检出相关病原体|NA|NA;","",df5_cc_stat$其它病原,fixed = TRUE)
df5_cc_stat$其它病原 = gsub("未检出相关病原体|NA|NA","",df5_cc_stat$其它病原,fixed = TRUE)

df5_cc_qc = df1 %>% select(sample,质控评价) %>% distinct() #添加质控评价信息
df5_cc_stat = df5_cc_stat %>% left_join(df5_cc_qc,by = c("sample" = "sample"))



##后续你需要直接将  人内参ZXF，人内参ACTB，人内参XXX全部相加
list_columns <- sapply(df5_cc_stat, is.list)
df5_cc_stat[, list_columns] <- lapply(df5_cc_stat[, list_columns], function(x) sapply(x, function(y) paste(y, collapse = ";")))
df5_cc_stat <- df5_cc_stat %>%
  mutate(总人内参 = rowSums(select(., contains("人内参")) %>% mutate_all(as.numeric), na.rm = TRUE)) %>% 
  select(run,date,sample,体系,tag,tag_sample,原始数据,Q30,目标病原,目标病原RPK,目标病原预判, matches("总人内参|外源内参"),
         其它病原,resis_info,质控评价,patho_namezn,生产批号,产品检类别,成品对应中间品批号,生产工艺,核酸提取日期,核酸重复次数,
         提取重复次数,文库浓度,Pooling体积)



#自定义排序函数
custom_sort <- function(x) {
  order_numbers <- as.numeric(sub(".*\\|", "", x))
  ordered_x <- x[order(-order_numbers)]  # 设置为降序排序
  return(ordered_x)
}

df5_cc_stat <- df5_cc_stat %>%
  mutate(其它病原 = sapply(strsplit(其它病原, ";"), function(x) {
    sorted_text <- custom_sort(x)
    paste(sorted_text, collapse = ";")
  }))


#要判断必要信息是否存在，没有则添加上去
if (!("外源内参" %in% names(df5_cc_stat))){
  df5_cc_stat$外源内参 = 0
}
if (!("总人内参" %in% names(df5_cc_stat))){
  df5_cc_stat$总人内参 = 0
}
if (!("目标病原RPK" %in% names(df5_cc_stat))){
  df5_cc_stat$目标病原RPK = 0
}
df5_cc_stat <- df5_cc_stat %>% mutate_at(vars(原始数据, Q30,目标病原RPK,外源内参,总人内参), as.numeric)  
df5_cc_stat$resis_info = gsub("c\\(\"", "",df5_cc_stat$resis_info) 
df5_cc_stat$resis_info = gsub("\"\\)", "",df5_cc_stat$resis_info)
df5_cc_stat$resis_info = gsub("\", \"", ";",df5_cc_stat$resis_info)



####添加最终评价：
#########################################################################################
# tag_sample为临床样本时，最终评价为质控评价
# tag_sample为NTC 时：其它病原 没有检出 阳性病原 且耐药都小于500，即为合格，否则不合格
# 检测限参考品：检出目标病原为阳性，外源内参大于50，其余病原 没有检出 阳性病原 且耐药都小于500，即为合格，否则不合格；（注：目标病原为百日咳，耐药检出百日咳耐药：都为合格）
# 阳性参考品：检出目标病原为阳性，外源内参大于50，其余病原 没有检出 阳性病原 且耐药都小于500，即为合格，否则不合格；（注：目标病原为百日咳，耐药检出百日咳耐药：都为合格）
# 阴性参考品：总人内参 < 200且 外源内参>50且其余病原 没有检出 阳性病原 且耐药都小于500，即为合格，否则不合格
# 阴性对照品：外源内参>50且其余病原 没有检出 阳性病原 且耐药都小于500，即为合格，否则不合格
# 阳性对照品：检出阳性对照品为阳性，外源内参大于50，其余病原 没有检出 阳性病原 且耐药都小于500，即为合格，否则不合格
# 重复性参考品 :检出目标病原为阳性，外源内参大于50，其余病原 没有检出 阳性病原 且耐药都小于500，即为合格，否则不合格；（注：目标病原为百日咳，耐药检出百日咳耐药：都为合格）



##20260627修改：1：简化代码；2：修改目标病原是百日咳可能会给出最终评价为不合格的bug  
#主要是resis_info会出现为空的情况（检测线参考品、重复性参考品、阳性参考品的样本）
# 定义检查函数
check_condition <- function(data, column) {
  sapply(strsplit(data[[column]], ";"), function(x) {
    values <- as.numeric(sapply(strsplit(x, "\\|"), `[`, 3))
    values[is.na(values)] <- 0
    all(values < 500)
  })
}

check_condition2 <- function(data, column) {
  sapply(strsplit(data[[column]], ";"), function(x) {
    values <- sapply(strsplit(x, "\\|"), `[`, 2)
    values[is.na(values)] <- "滤"
    all(values == "滤")
  })
}

# 替换 NA 值
df5_cc_stat <- df5_cc_stat %>%
  mutate(
    其它病原 = ifelse(其它病原 == "NA|NA|NA", NA, 其它病原),
    外源内参 = replace_na(外源内参, 0),
    总人内参 = replace_na(总人内参, 0),
    目标病原 = replace_na(目标病原, "")
  )

# 中间变量存储检查结果
resis_info_check <- check_condition(df5_cc_stat, "resis_info")
other_pathogen_check <- check_condition2(df5_cc_stat, "其它病原")

# 更新最终评价列
##20240705 阴性参考品的合格标准：总人内参 < 200；即不合格原因更改为 总人内参 ≥ 200
df5_cc_stat <- df5_cc_stat %>%
  mutate(
    最终评价 = case_when(
      tag_sample == "临床样本" ~ 质控评价,
      tag_sample == "NTC" & resis_info_check & other_pathogen_check ~ "合格",
      tag_sample == "阴性参考品" & resis_info_check & other_pathogen_check & 总人内参 < 200 ~ "合格",
      tag_sample == "阴性对照品" & resis_info_check & other_pathogen_check & 外源内参 > 50 ~ "合格",
      tag_sample == "阳性对照品" & resis_info_check & other_pathogen_check & 外源内参 > 50 & 目标病原预判 != "滤" ~ "合格",
      tag_sample == "检测限参考品" & resis_info_check & other_pathogen_check & 外源内参 > 50 & 目标病原预判 != "滤" & !str_detect(目标病原, "百日咳") ~ "合格",
      tag_sample == "检测限参考品" & other_pathogen_check & 外源内参 > 50 & 目标病原预判 != "滤" & str_detect(目标病原, "百日咳") & str_detect(resis_info, "百日咳|NULL") ~ "合格",
      tag_sample == "阳性参考品" & resis_info_check & other_pathogen_check & 外源内参 > 50 & 目标病原预判 != "滤" & !str_detect(目标病原, "百日咳") ~ "合格",
      tag_sample == "阳性参考品" & other_pathogen_check & 外源内参 > 50 & 目标病原预判 != "滤" & str_detect(目标病原, "百日咳") & str_detect(resis_info, "百日咳|NULL") ~ "合格",
      tag_sample == "重复性参考品" & resis_info_check & other_pathogen_check & 外源内参 > 50 & 目标病原预判 != "滤" & !str_detect(目标病原, "百日咳") ~ "合格",
      tag_sample == "重复性参考品" & other_pathogen_check & 外源内参 > 50 & 目标病原预判 != "滤" & str_detect(目标病原, "百日咳") & str_detect(resis_info, "百日咳|NULL") ~ "合格",
      TRUE ~ "不合格"
    )
  )


##20240510修改：
# 1：添加一个不合格的原因：原始数据不合格的样本，最终评价为不合格
# 2：最终评价原意是不合格，但写法有其它规则的，统一替换为不合格
## 20240705修改：原始数据量不合格标准 ： ≤ 50000
df5_cc_stat = df5_cc_stat %>% 
  mutate(最终评价 = case_when(
    str_detect(最终评价,"不合格") ~ "不合格",
    原始数据 <= 50000 ~ "不合格",
    TRUE ~ 最终评价
  ))




###20240507修改；对最终评价不合格的添加不合格原因：
###20240510修改；不合格原因中添加一个“原始数据不合格”的原因
###20240702修改；对比未检出目标病原的情况，不合格原因修改为：目标病原漏检
###20240705修改；原始数据量不合格标准 ： ≤ 50000
df5_cc_stat <- df5_cc_stat %>%
  mutate(不合格原因 = case_when(
    str_detect(最终评价,"不合格") & tag_sample == "临床样本" ~ 质控评价,
    str_detect(最终评价,"不合格") & tag_sample %in% c("NTC", "阳性参考品","检测限参考品","阴性参考品","阴性对照品","重复性参考品","阳性对照品")
    & 原始数据 <= 50000 ~ "原始数据不合格",
    str_detect(最终评价,"不合格") & tag_sample %in% c("阳性参考品","检测限参考品","重复性参考品","阳性对照品")
    & (目标病原预判 == "滤" | is.na(目标病原预判)) ~ "目标病原漏检",
    str_detect(最终评价,"不合格") & tag_sample %in% c("NTC", "阳性参考品","检测限参考品","阴性参考品","阴性对照品","重复性参考品","阳性对照品")
    & str_detect(其它病原, "阳") ~ "病原污染",
    str_detect(最终评价,"不合格") & tag_sample %in% c("NTC", "阳性参考品","检测限参考品","阴性参考品","阴性对照品","重复性参考品","阳性对照品")
    & !check_condition(., "resis_info") & !str_detect(目标病原,"百日咳") ~ "耐药污染",
    str_detect(最终评价,"不合格") & tag_sample %in% c( "阳性参考品","检测限参考品","阴性对照品","重复性参考品","阳性对照品")
    & 外源内参 <= 50  ~ "外源内参不合格",
    str_detect(最终评价,"不合格") & tag_sample == "阴性参考品"
    & 总人内参 >= 200  ~ "人内参不合格",
    TRUE ~ NA_character_
  ))


#20240509修改：针对甲流和甲流2009的情况处理：有2009就按2009 没有2009就按甲流
# 按照sample分组，检查是否同时存在"甲型"和"甲型2009"
df5_cc_stat <- df5_cc_stat %>%
  group_by(sample) %>%
  mutate(has_2009 = any(patho_namezn == "甲型流感病毒H1N1(2009)")) %>%
  mutate(has_2009 = replace_na(has_2009, FALSE)) %>% 
  filter(!(patho_namezn == "甲型流感病毒" & has_2009)) %>%
  select(-has_2009)

df5_cc_stat_final = df5_cc_stat %>% select(run,sample,tag_sample,最终评价,不合格原因) %>% 
  rename("RUN" = "run","实验编号" = "sample","文库编号" = "tag_sample") %>% as_tibble()




###添加污染检测表格:df5_cc_other_patho
##########################################################################
df5_cc_other_patho = df5 %>% filter(tag_sample %in% c("NTC","检测限参考品","阳性参考品","阴性参考品","阴性对照品","阳性对照品","重复性参考品")) %>% 
  filter(!is.na(tag_sample)) 


if (nrow(df5_cc_other_patho) > 0){
  df5_cc_other_patho <- df5_cc_other_patho %>%
    group_by(生产批号) %>%
    mutate(same_batch_num = n_distinct(sample)) %>% ungroup()
  
  df5_cc_other_patho =
    df5_cc_other_patho%>% group_by(生产批号,same_batch_num,patho_tag,patho_namezn) %>% 
    summarise(total_sample = n(),
              RPK_median = median(patho_RPK,na.rm = TRUE),
              .groups = "drop") %>% 
    filter(patho_tag == "外源病原") %>% 
    mutate(sample_frequency = total_sample / same_batch_num) %>% ungroup() %>% 
    select(-patho_tag)
  
  
}


##添加百日咳和肺炎的信息：
df5_cc_other_patho_2 = df5 %>% filter(tag_sample %in% c("NTC","检测限参考品","阳性参考品","阴性参考品","阴性对照品","阳性对照品","重复性参考品")) %>% 
  filter(!is.na(tag_sample))

df5_cc_other_patho_2 <- df5_cc_other_patho_2 %>%
  group_by(生产批号) %>%
  mutate(same_batch_num = n_distinct(sample)) %>% ungroup()

df5_cc_other_patho_2 = df5_cc_other_patho_2 %>% 
  filter(!(型别 %in% c("百日咳鲍特菌","肺炎支原体"))) %>% 
  filter(!is.na(drug_info))

if(nrow(df5_cc_other_patho_2) > 0){
  df5_cc_other_patho_2 = df5_cc_other_patho_2 %>% 
    separate(drug_info, sep = "\\|", c("patho","drug","RPK"), remove = TRUE) %>%
    select(sample, 生产批号,patho, RPK,same_batch_num) %>% 
    distinct() %>% 
    group_by(生产批号,same_batch_num,patho) %>% 
    summarise(total_sample = n(),
              RPK_median = median(as.numeric(RPK), na.rm = TRUE),
              .groups = "drop") %>% 
    mutate(sample_frequency = total_sample / same_batch_num)
  
  df5_cc_other_patho_2$RPK_median = as.numeric(df5_cc_other_patho_2$RPK_median)  
  df5_cc_other_patho_2 = df5_cc_other_patho_2 %>% rename("patho_namezn" = "patho") %>% ungroup()
}


if(nrow(df5_cc_other_patho_2) > 0 & nrow(df5_cc_other_patho) > 0){
  df5_cc_other_patho =df5_cc_other_patho %>%  full_join(df5_cc_other_patho_2)
} else if (nrow(df5_cc_other_patho_2) > 0 & nrow(df5_cc_other_patho) == 0) {
  df5_cc_other_patho = df5_cc_other_patho2
} else if (nrow(df5_cc_other_patho_2) == 0 & nrow(df5_cc_other_patho) > 0){
  df5_cc_other_patho = df5_cc_other_patho
}


#添加生信预判:不合格：PK_median > 20  & ratio > 0.5；而对于百日咳耐药的，调整其不合格阈值：RPK median > 500
if(nrow(df5_cc_other_patho) > 0){
  df5_cc_other_patho = df5_cc_other_patho %>% 
    mutate(生信预判 = case_when(
      !str_detect(patho_namezn,"百日咳") & sample_frequency > 0.5 & RPK_median > 20 ~ "不合格",
      str_detect(patho_namezn,"百日咳") & sample_frequency > 0.5 & RPK_median > 500 ~ "不合格",
      TRUE ~ "合格"
    ))
}

#20240510修改：污染病原为空的，删除掉该行
df5_cc_other_patho = df5_cc_other_patho %>% filter(!is.na(patho_namezn))

##########################################################################





####对比分析：添加if函数；识别质检模板.xlsx中的 "表2-对比信息表"
#################################################################################
sample_compare_df = read.xlsx(args$input5,sheet = "表2-对比信息表") #核对名称是否规范

##判断sample_compare_df中是否为空，非空才执行；
if (nrow(sample_compare_df) > 0){
  sample_compare_df = sample_compare_df %>% 
    mutate(Group = row_number(),con_DJ = "DJ",con_LY = "LY") %>% 
    rename("sample_DJ" = "待检试剂-对应文库","sample_LY" = "留样试剂-对应文库") %>% 
    select(Group,sample_DJ,con_DJ,sample_LY,con_LY)
  
  # 使用tryCatch()来捕获可能的错误
  tryCatch({
    check_columns(sample_compare_df, c("Group","sample_DJ","con_DJ","sample_LY","con_LY"))
  }, error = function(e) {
    print(paste("错误:", e$message))
  })
  
  ##企参样本对比分析：df6_stat
  ##仅对企参样本进行分析
  ########################################################
  df6_1 <- left_join(sample_compare_df, df5_cc_stat, by = c("sample_DJ" = "sample")) %>% 
    select(-c(date,目标病原预判,其它病原))
  df6_2 <- left_join(df6_1, df5_cc_stat, by = c("sample_LY" = "sample"),suffix=c("_DJ","_LY")) %>% 
    select(-c(date,目标病原预判,其它病原))
  df6_stat  =df6_2 %>% select(run_DJ,体系_DJ,tag_DJ,tag_sample_DJ,目标病原_DJ,sample_DJ,sample_LY,原始数据_DJ,原始数据_LY,
                              Q30_DJ,Q30_LY,目标病原RPK_DJ,目标病原RPK_LY,外源内参_DJ,外源内参_LY,总人内参_DJ,总人内参_LY,
                              resis_info_DJ,resis_info_LY,质控评价_DJ,质控评价_LY,
                              生产批号_DJ,生产批号_LY,文库浓度_DJ,文库浓度_LY,最终评价_DJ,最终评价_LY,不合格原因_DJ,不合格原因_LY) %>% 
    rename(run = run_DJ,体系= 体系_DJ, tag = tag_DJ,tag_sample = tag_sample_DJ,目标病原 = 目标病原_DJ)
  ########################################################
  
  
  
  ##输出待检-留样对比 表：df5_all_compare
  #对比中的所有样本中的所有病原都进行DJ—LY的对比，
  ########################################################
  df5_all_compare_origal = df5
    # # #添加最终评价：
  df5_cc_stat_final_cut = df5_cc_stat_final %>% select(-不合格原因)
  df5_all_compare_origal = df5_all_compare_origal %>% 
    left_join(df5_cc_stat_final_cut,by=c("run" = "RUN","sample" = "实验编号","tag_sample"= "文库编号"))

  df5_all_compare_origal <- df5_all_compare_origal %>%group_by(sample) %>%
    mutate(`总人内参` = sum(ifelse(str_detect(patho_tag, "人内参"), patho_RPK, 0)),
           `外源内参` = sum(ifelse(str_detect(patho_tag, "外源内参"), patho_RPK, 0))) %>% 
    select(run,体系,date,sample,tag,tag_sample,型别,原始数据,Q30,外源内参,总人内参,patho_namezn,文库浓度,
           drug_info,filter_flag,patho_RPK,质控评价,最终评价)
  
  sample_compare_df2 <- sample_compare_df %>%
    pivot_longer(cols = c(sample_DJ, sample_LY), 
                 names_to = "con", 
                 values_to = "sample") %>%
    mutate(con = gsub("sample_", "", con)) %>% 
    select(-c(con_DJ,con_LY))
  
  df5_all_compare = df5_all_compare_origal %>% left_join(sample_compare_df2,by = c("sample" = "sample"))
  df5_all_compare$patho_RPK = as.numeric(df5_all_compare$patho_RPK)
  df5_all_compare$原始数据 = as.numeric(df5_all_compare$原始数据)
  df5_all_compare$Q30 = as.numeric(df5_all_compare$Q30)
  
  
  #解决：! Can't convert `fill` <double> to <list>.的问题
  df5_all_compare =df5_all_compare %>%  filter(!is.na(Group))
  df5_all_compare_temp <- df5_all_compare %>%
    group_by(Group, patho_namezn, con) %>%
    summarise(patho_RPK = sum(patho_RPK),
              .groups = "drop") %>%
    distinct() %>%
    pivot_wider(id_cols = c(Group, patho_namezn), names_from = con, values_from = patho_RPK, values_fill = 0) %>%
    rename(patho_rpk_DJ = DJ, patho_rpk_LY = LY) %>%ungroup()
  
  
  df5_all_compare_temp = 
    df5_all_compare_temp %>% left_join(sample_compare_df,by=c("Group" = "Group")) %>% 
    select(-c(con_DJ,con_LY)) %>%
    left_join(df5_all_compare %>% select(-c(patho_RPK,patho_namezn)),by=c("sample_DJ" = "sample"),relationship = "many-to-many") %>% 
    left_join(df5_all_compare %>% select(-c(patho_RPK,patho_namezn)),by=c("sample_LY"="sample"), suffix=c("_DJ","_LY"),relationship = "many-to-many") %>% 
    rename(体系=体系_DJ,date = date_DJ,tag = tag_DJ,run = run_DJ) %>% 
    select(run,体系,date,tag,sample_DJ,sample_LY,tag_sample_DJ,tag_sample_LY,型别_DJ,型别_LY,原始数据_DJ,原始数据_LY,Q30_DJ,Q30_LY,总人内参_DJ,总人内参_LY,
           外源内参_DJ,外源内参_LY,patho_namezn,patho_rpk_DJ,patho_rpk_LY,质控评价_DJ,质控评价_LY,文库浓度_DJ,文库浓度_LY,最终评价_DJ,最终评价_LY,drug_info_DJ,drug_info_LY)%>% distinct() 
  
  
  ##添加filter_flag
  df5_all_compare_filter_info = df5_all_compare %>% select(sample,patho_namezn,filter_flag) %>% distinct()
  df5_all_compare_temp = df5_all_compare_temp %>% 
    left_join(df5_all_compare_filter_info,by=c("sample_DJ" = "sample","patho_namezn" = "patho_namezn"),relationship = "many-to-many") %>% 
    left_join(df5_all_compare_filter_info,by=c("sample_LY"="sample","patho_namezn" = "patho_namezn"), suffix=c("_DJ","_LY"),relationship = "many-to-many") %>% 
    distinct()
  
  
  ###添加同一种病原计数信息
  df5_all_compare = df5_all_compare_temp
  df5_all_compare=
    df5_all_compare %>%  
    group_by(patho_namezn) %>%
    mutate(count = n())
  
  ##剔除部分重名的病原：后续也要单独核对，以防止重名病原遗漏。
  df5_all_compare = df5_all_compare %>% 
    filter(!patho_namezn %in% c("肠道病毒","肠道病毒A组","人腺病毒E组","人腺病毒C组","人腺病毒21型","人腺病毒B组","人腺病毒")) 
  
  ##双向补充，tag_sample 信息
  df5_all_compare <- df5_all_compare %>%
    mutate(tag_sample_DJ = coalesce(tag_sample_DJ, tag_sample_LY),
           tag_sample_LY = coalesce(tag_sample_LY, tag_sample_DJ))
  
  
  ##添加生产批号：
  df5_all_batch = df3 %>% select(文库编号,生产批号) %>% distinct() %>% rename("sample" = "文库编号")
  df5_all_compare = df5_all_compare %>% left_join(df5_all_batch,by=c("sample_LY" = "sample")) %>% rename("生产批号_LY" = "生产批号")
  df5_all_compare = df5_all_compare %>% left_join(df5_all_batch,by=c("sample_DJ" = "sample")) %>% rename("生产批号_DJ" = "生产批号")
  
df5_all_compare = df5_all_compare %>% filter((str_detect(drug_info_DJ,"肺炎") & str_detect(drug_info_LY,"肺炎")) |
                                                 (str_detect(drug_info_DJ,"百日咳") & str_detect(drug_info_LY,"百日咳")) |
                                                 is.na(drug_info_DJ) | is.na(drug_info_LY))

                                                 
  df5_all_compare$patho_rpk_DJ[is.na(df5_all_compare$patho_rpk_DJ)] <- 0
  df5_all_compare$patho_rpk_LY[is.na(df5_all_compare$patho_rpk_LY)] <- 0
  ########################################################  
} else{
  print("没有对比信息")
}




###20240506修改；修改Excel的顺序
df5_cc_other_patho_final = df5_cc_other_patho %>% rename(
  "总样本数" = "same_batch_num",
  "病原名" = "patho_namezn",
  "检出样本数" = "total_sample",
  "病原RPK中位数" = "RPK_median",
  "样本频率" = "sample_frequency"
) %>% as_tibble()


##20240508修订：修改df5_all_compare的表头
df5_all_compare = df5_all_compare %>% 
  select(run,体系,tag,tag_sample_DJ,patho_namezn,sample_DJ,sample_LY,patho_rpk_DJ,patho_rpk_LY,
         原始数据_DJ,原始数据_LY,Q30_DJ,Q30_LY,外源内参_DJ,外源内参_LY,总人内参_DJ,
         总人内参_LY,质控评价_DJ,质控评价_LY,生产批号_LY,生产批号_DJ,filter_flag_DJ,filter_flag_LY,
         文库浓度_DJ,文库浓度_LY,最终评价_DJ,最终评价_LY,drug_info_DJ,drug_info_LY) %>% 
  rename("检出病原" = "patho_namezn","tag_sample" = "tag_sample_DJ",
         "检出病原RPK_DJ" = "patho_rpk_DJ","检出病原RPK_LY" = "patho_rpk_LY")

#20240509修改：都把DJ放前，LY放后：
df5_all_compare2 =df5_all_compare
df6_stat2 = df6_stat

colnames(df5_all_compare2) <- gsub("^_", "", gsub("(.*)(_DJ)", "\\2_\\1", colnames(df5_all_compare2)))
colnames(df5_all_compare2) <- gsub("^_", "", gsub("(.*)(_LY)", "\\2_\\1", colnames(df5_all_compare2)))
colnames(df6_stat2) <- gsub("^_", "", gsub("(.*)(_DJ)", "\\2_\\1", colnames(df6_stat2)))
colnames(df6_stat2) <- gsub("^_", "", gsub("(.*)(_LY)", "\\2_\\1", colnames(df6_stat2)))



##写入保存
################################################################################
df5_cc_stat = df5_cc_stat %>% as.data.frame()
df5_cc_stat  <- df5_cc_stat  %>%
  mutate(其它病原 = ifelse(其它病原 == "NA|NA|NA", NA, 其它病原))
data_frames <- list(
  "汇总" = df5_cc_stat
)
# 判断这些DF是否存在，若存在则添加到数据帧列表中
if (exists("df6_stat")) {
  data_frames[["QC对比"]] <- as.data.frame(df6_stat2)
} 
if (exists("df5_all_compare")) {
  data_frames[["待检-留样对比"]] <- as.data.frame(df5_all_compare2)
}
if (exists("df5_cc_stat_final")) {
  data_frames[["2.2各文库合格标准评估"]] <- as.data.frame(df5_cc_stat_final)
} 
if (exists("df5_cc_other_patho_final")) {
  data_frames[["2.3各病原污染情况评估"]] <- as.data.frame(df5_cc_other_patho_final)
}
if (exists("messages_df")) {
  data_frames[["其余信息"]] <- as.data.frame(messages_df)
}
write.xlsx(data_frames, file = args$output1)
################################################################################






##画对比散点图pdf;按照体系区分；
################################################################################
# 创建一个空的列表来存储所有的图形对象
all_plots <- list()
tixi = df5_cc_stat $体系 %>% unique()
tixi_n = length(tixi)




#####所有样本中的质控散点图,按照体系来绘制
################################################################################
if (nrow(sample_compare_df) > 0){
  for (i in 1:tixi_n) {
    tixi_item = tixi[i]
    df6_stat_tixi = df6_stat %>% filter(体系 == tixi_item)

    compare_list = c("原始数据","Q30","总人内参","外源内参")
    compare_n = length(compare_list)
    
    for (k in 1:compare_n) {
      compare_item = compare_list[k]
      
      df6_stat_clean <- df6_stat_tixi[
        is.finite(df6_stat_tixi[[paste0(compare_item, "_DJ")]]) & 
          is.finite(df6_stat_tixi[[paste0(compare_item, "_LY")]]),]
      
      if (nrow(df6_stat_clean) > 0) {
        # 绘制图形
        duibi_p <- ggplot(df6_stat_clean, aes_string(
          x = paste0(compare_item, "_DJ"), 
          y = paste0(compare_item, "_LY"),
          color = "tag_sample",shape = "生产批号_DJ"
        )) + 
          geom_point(size = 1.5,alpha = 0.4) + 
          geom_abline(intercept = 0, slope = 1, color = "#FF6600", linetype = "dashed",linewidth = 1) +
          geom_abline(intercept = 0, slope = 0.5, color = "green",linetype = "dashed",linewidth = 0.3) +
          geom_abline(intercept = 0, slope = 0.25, color = "red",linetype = "dashed",linewidth = 0.3) +   
          geom_abline(intercept = 0, slope = 2, color = "red",linetype = "dashed",linewidth = 0.3) + 
          geom_abline(intercept = 0, slope = 4, color = "green",linetype = "dashed",linewidth = 0.3) +
          scale_x_continuous(limits = c(0,max(df6_stat_clean[[paste0(compare_item, "_DJ")]], df6_stat_clean[[paste0(compare_item, "_LY")]]))) +
          scale_y_continuous(limits = c(0,max(df6_stat_clean[[paste0(compare_item, "_DJ")]], df6_stat_clean[[paste0(compare_item, "_LY")]])))+
          coord_fixed() + 
          theme_bw() + 
          ggtitle(paste0(tixi_item,"-",compare_item, "-所有样本", "-对比"))+
          theme(panel.grid = element_blank(),
                text = element_text(size = 8), 
                axis.text = element_text(size = 6), 
                axis.title = element_text(size = 6),
                plot.title = element_text(size = 8), 
                legend.text = element_text(size = 6), 
                legend.title = element_text(size = 6) 
          )
        
        # 将图形对象添加到列表中
        all_plots[[paste0(tixi_item,"-duibi_qc-", compare_item)]] <- duibi_p
      }
    }
  }
} else{
  print("没有DJ和LY的对比信息，无法绘制质控散点图")
}
################################################################################



####绘制总病原散点图：包括企参和临床病原的
################################################################################
if (nrow(sample_compare_df) > 0){
  
  compare_all_patho = df5_all_compare
  
  for (i in 1:tixi_n) {
    tixi_item = tixi[i]
    compare_all_patho_tixi = compare_all_patho %>% filter(体系 == tixi_item)
    
    
    if (nrow(compare_all_patho_tixi) > 0) {
      patho_all_p <- ggplot(compare_all_patho_tixi, aes(检出病原RPK_DJ,检出病原RPK_LY,color = tag_sample,shape = 生产批号_DJ)) + 
        geom_point(size = 1.5,alpha = 0.4) +
        geom_abline(intercept = 0, slope = 1, color = "#FF6600", linetype = "dashed",linewidth = 1) +
        geom_abline(intercept = 0, slope = 0.5, color = "green",linetype = "dashed",linewidth = 0.3) +
        geom_abline(intercept = 0, slope = 0.25, color = "red",linetype = "dashed",linewidth = 0.3) +   
        geom_abline(intercept = 0, slope = 2, color = "red",linetype = "dashed",linewidth = 0.3) + 
        geom_abline(intercept = 0, slope = 4, color = "green",linetype = "dashed",linewidth = 0.3) +
        scale_x_continuous(limits = c(0,max(compare_all_patho_tixi$检出病原RPK_DJ, compare_all_patho_tixi$检出病原RPK_LY, na.rm = TRUE))) +
        scale_y_continuous(limits = c(0,max(compare_all_patho_tixi$检出病原RPK_DJ, compare_all_patho_tixi$检出病原RPK_LY, na.rm = TRUE))) +
        coord_fixed() + theme_bw() + ggtitle(paste0(tixi_item,"-所有病原", "-对比")) +
        theme(panel.grid = element_blank(),
              text = element_text(size = 8), 
              axis.text = element_text(size = 6), 
              axis.title = element_text(size = 6),
              plot.title = element_text(size = 8), 
              legend.text = element_text(size = 6), 
              legend.title = element_text(size = 6) 
        )
      # 将图形对象添加到列表中
      all_plots[[paste0(tixi_item,"-patho_p-","所有病原")]] <- patho_all_p
    }
  }
  
}else{
  print ("没有DJ和LY的对比信息，无法绘制总病原散点图")
}
################################################################################



##绘制目标病原RPK
################################################################################
if (nrow(sample_compare_df) > 0){
  for (i in 1:tixi_n) {
    tixi_item = tixi[i]
    df6_stat_tixi = df6_stat %>% filter(体系 == tixi_item)
    
    compare_list = "目标病原RPK"
    compare_n = length(compare_list)
    
    for (k in 1:compare_n) {
      compare_item = compare_list[k]
      
      df6_stat_clean <- df6_stat_tixi[
        is.finite(df6_stat_tixi[[paste0(compare_item, "_DJ")]]) & 
          is.finite(df6_stat_tixi[[paste0(compare_item, "_LY")]]),]
      
      if (nrow(df6_stat_clean) > 0) {
        # 绘制图形
        duibi_p <- ggplot(df6_stat_clean, aes_string(
          x = paste0(compare_item, "_DJ"), 
          y = paste0(compare_item, "_LY"),
          color = "tag_sample",shape = "生产批号_DJ"
        )) + 
          geom_point(size = 1.5,alpha = 0.4) + 
          geom_abline(intercept = 0, slope = 1, color = "#FF6600", linetype = "dashed",linewidth = 1) +
          geom_abline(intercept = 0, slope = 0.5, color = "green",linetype = "dashed",linewidth = 0.3) +
          geom_abline(intercept = 0, slope = 0.25, color = "red",linetype = "dashed",linewidth = 0.3) +   
          geom_abline(intercept = 0, slope = 2, color = "red",linetype = "dashed",linewidth = 0.3) + 
          geom_abline(intercept = 0, slope = 4, color = "green",linetype = "dashed",linewidth = 0.3) +
          scale_x_continuous(limits = c(0,max(df6_stat_clean[[paste0(compare_item, "_DJ")]], df6_stat_clean[[paste0(compare_item, "_LY")]]))) +
          scale_y_continuous(limits = c(0,max(df6_stat_clean[[paste0(compare_item, "_DJ")]], df6_stat_clean[[paste0(compare_item, "_LY")]])))+
          coord_fixed() + 
          theme_bw() + 
          ggtitle(paste0(tixi_item,"-",compare_item, "-所有样本", "-对比"))+
          theme(panel.grid = element_blank(),
                text = element_text(size = 8), 
                axis.text = element_text(size = 6), 
                axis.title = element_text(size = 6),
                plot.title = element_text(size = 8), 
                legend.text = element_text(size = 6), 
                legend.title = element_text(size = 6) 
          )
        
        # 将图形对象添加到列表中
        all_plots[[paste0(tixi_item,"-duibi_qc-", compare_item)]] <- duibi_p
      }
    }
  }
} else{
  print("没有DJ和LY的对比信息，无法绘制质控散点图")
}
################################################################################






####对所有病原的对比散点图:按体系区分；企参的和临床的放在一起
################################################################################
if (nrow(sample_compare_df) > 0){
  for (i in 1:tixi_n) {
    tixi_item = tixi[i]
    compare_specif_df = df5_all_compare %>% filter(体系 == tixi_item)
    
    # ##20240509修订：修改三叶草的名称为外源内参
    compare_specif_df = compare_specif_df %>% mutate(检出病原 = case_when(
      检出病原 == "三叶草根瘤菌(NA)" ~ "外源内参",
      TRUE ~ 检出病原
    ))
    
    compare_specif_list = compare_specif_df$检出病原[!is.na(compare_specif_df$检出病原) & compare_specif_df$检出病原 != "" &
                                                           compare_specif_df$检出病原 !="/"] %>% unique()
    compare_specif_list <- stri_sort(compare_specif_list, locale = "zh_CN")
    compare_specif_n = length(compare_specif_list)
    
    
    
    
    for (j in 1:compare_specif_n) {
      compare_specif_item = compare_specif_list[j]
      compare_specif_df_plot <- compare_specif_df %>% filter(检出病原 == compare_specif_item)
      
      if (nrow(compare_specif_df_plot) > 0) {
        #处理标准：
        # 1、质控判断都合格
        # 2、DJ、LY的病原预判至少有一个是阳性或弱阳或内参
        # 3、RPK_sum>30
        # 满足这三个条件，点颜色为蓝色（N=蓝色点的数目），否则为红色
        # 4、各样本各病原比值r1=DJ/LY，（LY=0则r1=DJ）:如果DJ/LY超过5，就取5就行了
        compare_specif_df_plot <- compare_specif_df_plot %>% ungroup() %>% 
          mutate(检出病原RPK_DJ = as.numeric(检出病原RPK_DJ),
                 检出病原RPK_LY = as.numeric(检出病原RPK_LY),
                 RPK_sum = rowSums(select(., 检出病原RPK_DJ, 检出病原RPK_LY)),
                 RPK_ratio = ifelse(检出病原RPK_LY == 0, 检出病原RPK_DJ, 检出病原RPK_DJ / 检出病原RPK_LY))
     
        compare_specif_df_plot <- compare_specif_df_plot %>%
          mutate(plot_tag = case_when(
            grepl("不合格", 质控评价_DJ) | grepl("不合格", 质控评价_LY) |
              (!grepl("阳|内参", filter_flag_DJ) & !grepl("阳|内参", filter_flag_LY))|
              RPK_sum < 30 ~ "不合格",
            TRUE ~ "合格"
          ))
        
        compare_specif_df_plot <- compare_specif_df_plot %>% 
          mutate(RPK_ratio = case_when(
            RPK_ratio > 5 ~ 5,
            TRUE ~ RPK_ratio
          ))
        
        # 绘制ratio图
        count <- compare_specif_df_plot %>% filter(plot_tag == "合格") %>% summarise(n=n())
        compare_specif_p2 <- ggplot(compare_specif_df_plot, aes(RPK_sum, RPK_ratio, color = plot_tag,shape = 生产批号_DJ)) + 
          geom_point(size = 1.5, alpha = 0.6) + 
          scale_color_manual(values = c("不合格" = "red", "合格" = "blue"))+
          geom_hline(yintercept = 1.0, color = "black", linewidth = 0.3) +
          geom_hline(yintercept = 0.7, color = "grey", linetype = "dashed", linewidth = 0.3) +
          geom_hline(yintercept = 0.5, color = "grey", linetype = "dashed", linewidth = 0.3) +
          # annotate("text", x=0,y=1.2, label="1.2", hjust=-2) +
          theme_bw() +           
          labs(y = "Patho_DJ/Patho_LY") +
          ggtitle(paste0(tixi_item,"-",compare_specif_item, "(n=",count$n,")"))+
          theme(panel.grid = element_blank(),
                text = element_text(size = 8), 
                axis.text = element_text(size = 6), 
                axis.title = element_text(size = 6),
                plot.title = element_text(size = 8), 
                legend.text = element_text(size = 6), 
                legend.title = element_text(size = 6) 
          )
        # 将图形对象添加到列表中
        all_plots[[paste0("1-patho_com",tixi_item,"_", compare_specif_item)]] <- compare_specif_p2
        
        
        
        # 绘制散点图
        compare_specif_p <- ggplot(compare_specif_df_plot, aes(检出病原RPK_DJ,检出病原RPK_LY,color = tag_sample,shape = 生产批号_DJ)) + 
          geom_point(size = 1.5,alpha = 0.4) + 
          geom_abline(intercept = 0, slope = 1, color = "#FF6600", linetype = "dashed",linewidth = 1) +
          geom_abline(intercept = 0, slope = 0.5, color = "green",linetype = "dashed",linewidth = 0.3) +
          geom_abline(intercept = 0, slope = 0.25, color = "red",linetype = "dashed",linewidth = 0.3) +   
          geom_abline(intercept = 0, slope = 2, color = "red",linetype = "dashed",linewidth = 0.3) + 
          geom_abline(intercept = 0, slope = 4, color = "green",linetype = "dashed",linewidth = 0.3) +
          scale_x_continuous(limits = c(0,max(compare_specif_df_plot$检出病原RPK_DJ, compare_specif_df_plot$检出病原RPK_LY))) +
          scale_y_continuous(limits = c(0,max(compare_specif_df_plot$检出病原RPK_DJ, compare_specif_df_plot$检出病原RPK_LY)))+
          coord_fixed() + 
          theme_bw() + 
          ggtitle(paste0(tixi_item,"-",compare_specif_item, "-对比"))+
          theme(panel.grid = element_blank(),
                text = element_text(size = 8), 
                axis.text = element_text(size = 6), 
                axis.title = element_text(size = 6),
                plot.title = element_text(size = 8), 
                legend.text = element_text(size = 6), 
                legend.title = element_text(size = 6) 
          )
        # 将图形对象添加到列表中
        all_plots[[paste0("2-patho_com",tixi_item,"_", compare_specif_item)]] <- compare_specif_p
        
      }
    }
    
    
    ##绘制耐药比对图：
    #######################################
    df5_all_compare_drug_plot = df5_all_compare %>% select(体系,sample_DJ,sample_LY,drug_info_DJ,drug_info_LY,tag_sample,生产批号_LY,生产批号_DJ) %>% 
      separate(drug_info_DJ,sep = "\\|",c("drug_name_DJ","drug_stat_DJ","drug_rpk_DJ"),remove = TRUE) %>% 
      separate(drug_info_LY,sep = "\\|",c("drug_name_LY","drug_stat_LY","drug_rpk_LY"),remove = TRUE)
    
    compare_all_patho =  df5_all_compare_drug_plot %>% 
      filter(!(is.na(drug_name_DJ) & is.na(drug_name_LY)))
    compare_all_patho <- compare_all_patho %>%
      mutate(drug_name_DJ = coalesce(drug_name_DJ, drug_name_LY),
             drug_name_LY = coalesce(drug_name_LY, drug_name_DJ)) %>% 
      select(-drug_name_LY) %>% rename("drug_name" = "drug_name_DJ")
    
    compare_all_patho$drug_rpk_DJ <- ifelse(is.na(compare_all_patho$drug_rpk_DJ), 0, as.numeric(compare_all_patho$drug_rpk_DJ))
    compare_all_patho$drug_rpk_LY <- ifelse(is.na(compare_all_patho$drug_rpk_LY), 0, as.numeric(compare_all_patho$drug_rpk_LY))
    compare_all_patho_tixi = compare_all_patho %>% filter(体系 == tixi_item)
    
    drug_terms = compare_all_patho_tixi$drug_name %>% unique()
    drug_n = length(drug_terms)
    
    for (j in 1:drug_n){
      compare_all_patho_tixi_drug = compare_all_patho_tixi %>% filter(drug_name == drug_terms[j])
      
      if (nrow(compare_all_patho_tixi_drug) > 0){
        drug_p <- 
          ggplot(compare_all_patho_tixi_drug, aes(drug_rpk_DJ,drug_rpk_LY,color = tag_sample,shape = 生产批号_DJ)) + 
          geom_point(size = 1.5,alpha = 0.4) +
          geom_abline(intercept = 0, slope = 1, color = "#FF6600", linetype = "dashed",linewidth = 1) +
          geom_abline(intercept = 0, slope = 0.5, color = "green",linetype = "dashed",linewidth = 0.3) +
          geom_abline(intercept = 0, slope = 0.25, color = "red",linetype = "dashed",linewidth = 0.3) +   
          geom_abline(intercept = 0, slope = 2, color = "red",linetype = "dashed",linewidth = 0.3) + 
          geom_abline(intercept = 0, slope = 4, color = "green",linetype = "dashed",linewidth = 0.3) +
          scale_x_continuous(limits = c(0,max(compare_all_patho_tixi_drug$drug_rpk_DJ, compare_all_patho_tixi_drug$drug_rpk_LY, na.rm = TRUE))) +
          scale_y_continuous(limits = c(0,max(compare_all_patho_tixi_drug$drug_rpk_DJ, compare_all_patho_tixi_drug$drug_rpk_LY, na.rm = TRUE))) +
          theme_bw() + ggtitle(paste0(tixi_item,"-",drug_terms[j], "-对比")) +
          theme(panel.grid = element_blank(),
                text = element_text(size = 8), 
                axis.text = element_text(size = 6), 
                axis.title = element_text(size = 6),
                plot.title = element_text(size = 8), 
                legend.text = element_text(size = 6), 
                legend.title = element_text(size = 6)
          )
        
        # 将图形对象添加到列表中
        all_plots[[paste0(tixi_item,"_", drug_terms[j])]] <- drug_p
      }
    }
  } 
}else {
  print("没有DJ和LY的对比信息，无法绘制单个病原对比分析图")
}

################################################################################
multi_page_plots <- marrangeGrob(all_plots, nrow = 2, ncol = 2,as.table=FALSE)
pdf(args$comparepdf, onefile = TRUE, family = "GB1")
print(multi_page_plots)
dev.off()



################################################################################





###型别一致的stat,并添加到回顾性信息表中
################################################################################
################################################################################
df7 = df5 %>% select(-drug_info,-resis_MutLog,-patho_tag) %>% 
  filter(体系 %in% c("T2P2","T3P2","T3P3") & !(tag_sample %in% c("临床样本","其它")))

##个性化调整
##################
df7 <- df7 %>%
  mutate(patho_namezn= case_when(
    grepl("人腮腺炎病毒2型（人副流感病毒2型）", patho_namezn) ~ "人副流感2型", ##修改名称以让patho_namezn和型别一致
    TRUE ~ patho_namezn 
  )) 
df7 <- df7 %>%
  mutate(patho_namezn= case_when(
    grepl("外源", patho_namezn) ~ "三叶草",
    TRUE ~ patho_namezn 
  )) 
df7 <- df7%>%
  mutate(tag= case_when(
    grepl("R1", tag) ~ "R01",
    grepl("R2", tag) ~ "R02",
    TRUE ~ tag 
  ))  
df7 <- df7%>%
  mutate(型别= case_when(
    grepl("阳性对照品",tag_sample) & grepl("枯草芽孢杆菌", 型别) ~ "阳性对照品",
    TRUE ~ 型别
  ))
df7_consist <- df7 %>%
  filter(str_detect(patho_namezn, fixed(型别)) | str_detect(patho_namezn, "三叶草") | 
           str_detect(patho_namezn, "内参")) 
#################

##添加至回顾性研究中
df7_old = read.xlsx(args$input6,sheet = "Sheet 1")
df7_old2 = read.xlsx(args$input6,sheet = "临床反馈")
# # result2_20240220_V7.xlsx 已经将之前病原名为枯草芽孢杆菌 全部修改为“阳性对照品”；同时tag按照【体系】-【编号】的规则来命名
# # result2_20240220_V8.xlsx 进一步调整之后的结果，将型别规范，包括“肠道病毒71型”修改为 “肠道病毒A71型”；“人副流感2型”修改为“人腮腺炎病毒2型（人副流感病毒2型）”


df7_old = df7_old %>%  select(run,date,体系,sample,tag,tag_sample,型别,proty,proid,prmty,生产批号,产品检类别,
                              成品对应中间品批号,生产工艺,核酸提取日期,核酸重复次数,提取重复次数,文库浓度,Pooling体积,
                              patho_namezn2,patho_namezn,filter_flag,patho_RPK,patho_reads,质控评价,QC_flag,临床反馈,原始数据,Q30,
                              过滤后数据量,质控合格比例,有效数据量,有效数据比例,提取试剂规格,提取试剂批号,企参编号,resis_name,
                              总人内参RPK)
df7_old <- lapply(df7_old, as.character) 
df7_old$patho_RPK = as.numeric(df7_old$patho_RPK)
df7_old <- as_tibble(df7_old)
df7_merge_orgin = full_join(df7_old,df7_consist) %>% distinct()
df7_merge_orgin <- df7_merge_orgin%>%
  mutate(QC_flag= case_when(
    grepl("不合格",质控评价)  ~ "质控不合格",
    TRUE ~ "质控合格"
  ))


#修改回顾性统计中的tag名称：读取config的retro_tagname_fix
retro_tagname_fix = read_excel(args$input7,sheet = "retro_tagname_fix")
for (i in 1:nrow(retro_tagname_fix)) {
  df7_merge_orgin <- df7_merge_orgin %>%
    mutate(tag = case_when(
      grepl(retro_tagname_fix$index[i], tag) ~ retro_tagname_fix$Fix_index[i],
      TRUE ~ tag
    ))
}
#patho_namezn进一步规范清洗：
df7_merge_orgin <- df7_merge_orgin%>%
  mutate(patho_namezn= case_when(
    grepl("三叶草",patho_namezn)  ~ "外源内参",
    (grepl("阳性对照品",型别) & grepl("枯草芽孢杆菌",patho_namezn)) ~ "阳性对照品",
    TRUE ~ patho_namezn
  ))

##数据清洗:将人内参相加为总人内参：注意去重
df7_merge_orgin <- df7_merge_orgin %>% distinct() %>% 
  group_by(run,体系,sample) %>%
  mutate(总人内参RPK = sum(patho_RPK[grepl("人内参", patho_namezn)]))

##写入到current_history_results_thistime.xlsx
df7_merge_orgin = df7_merge_orgin %>% as.data.frame()
df7_old2 = df7_old2 %>% as.data.frame()
df7_all <- list(
  "Sheet 1" = df7_merge_orgin,
  "临床反馈" = df7_old2
)
write.xlsx(df7_all,args$output2)



#####绘制回顾性图
################################################################################
# 创建一个空的列表来存储所有的图形对象
all_retro_plot <- list()
tixi = df7_consist$体系 %>% unique() #只绘制本轮实验的体系
tixi_n = length(tixi)

###绘制内参RPK分布图:包括内参和外源内参
for (i in 1:tixi_n){
  tixi_item = tixi[i]
  df7_merge = df7_merge_orgin %>% filter(体系 == tixi_item)
  df7_merge$log_RPK_value = log10(df7_merge$patho_RPK+1)
  df7_merge = df7_merge %>% 
    mutate(tag2 = case_when(
      grepl("LY",sample) & grepl(paste(args$date),date)~ "LY-new",
      grepl("DJ",sample) & grepl(paste(args$date),date)~ "DJ-new",
      grepl("LY",sample) & !grepl(paste(args$date),date)~ "LY-old",
      grepl("DJ",sample) & !grepl(paste(args$date),date)~ "DJ-old",
      TRUE ~ NA_character_,
    ))

  
  #绘制外源内参，1：所有的企参；2：NEG（阴性对照品）一张
  #####################################################
  df7_merge_plot_1 = df7_merge %>% 
    filter(tag_sample != "阴性对照品" & str_detect(patho_namezn, "外源内参"))
  df7_merge_plot_2 = df7_merge %>% 
    filter(tag_sample == "阴性对照品" & str_detect(patho_namezn, "外源内参"))
  
  if (nrow(df7_merge_plot_1) > 0 &&  !all(is.na(df7_merge_plot_1$tag2)) && any(df7_merge_plot_1$date == args$date, na.rm = TRUE)) {
    dates = tail(unique(df7_merge_plot_1$date), n = 20)
    ordered_dates <- dates[order(as.Date(dates, format = "%y%m%d"))]
    
    retro_p1 =
      ggplot(df7_merge_plot_1, aes(date, log_RPK_value)) + 
      geom_point(aes(color = tag2,shape=QC_flag),size = 0.6) + 
      scale_shape_manual(values = c("质控合格" = 20, "质控不合格" = 0))+
      scale_color_manual(values = c("LY-new" = "blue", "DJ-new" = "red","LY-old" = "#66CCFF","DJ-old" = "#FF9933")) +
      facet_wrap(~ 体系, scales = "free") +
      theme_bw() +
      scale_x_discrete(limits = rev(rev(ordered_dates))) +            ##设置X轴不超过60个时间点
      ggtitle(paste0(tixi_item,"-中外源内参的RPK分布及随时间的分布")) +
      theme(axis.text.x = element_text(angle = 90, hjust = 1),
            panel.grid = element_blank(),
            text = element_text(size = 8), 
            axis.text = element_text(size = 7), 
            axis.title = element_text(size = 6),
            plot.title = element_text(size = 8), 
            legend.text = element_text(size = 8), 
            legend.title = element_text(size = 8))
    all_retro_plot[[paste0("1-",tixi_item,"-中外源内参RPK分布")]] <- retro_p1
  }

  
  if (nrow(df7_merge_plot_2) > 0 && !all(is.na(df7_merge_plot_2$tag2)) && any(df7_merge_plot_2$date == args$date, na.rm = TRUE)) {
    dates = tail(unique(df7_merge_plot_2$date), n = 20)
    ordered_dates <- dates[order(as.Date(dates, format = "%y%m%d"))]
    
    retro_p2 =
      ggplot(df7_merge_plot_2, aes(date, log_RPK_value)) + 
      geom_point(aes(color = tag2,shape=QC_flag),size = 0.6) + 
      scale_shape_manual(values = c("质控合格" = 20, "质控不合格" = 0))+
      scale_color_manual(values = c("LY-new" = "blue", "DJ-new" = "red","LY-old" = "#66CCFF","DJ-old" = "#FF9933")) +
      facet_wrap(~ 体系, scales = "free") +
      theme_bw() +
      scale_x_discrete(limits = rev(rev(ordered_dates))) +            ##设置X轴不超过60个时间点
      ggtitle(paste0(tixi_item,"-阴性对照品-","中外源内参的RPK分布及随时间的分布")) +
      theme(axis.text.x = element_text(angle = 90, hjust = 1),
            panel.grid = element_blank(),
            text = element_text(size = 8), 
            axis.text = element_text(size = 7), 
            axis.title = element_text(size = 6),
            plot.title = element_text(size = 8), 
            legend.text = element_text(size = 8), 
            legend.title = element_text(size = 8))
    all_retro_plot[[paste0("1-",tixi_item,"-阴性对照品-","外源内参RPK分布")]] <- retro_p2
  }
  #####################################################
  
  
  
  ##绘制总人内参
  #####################################################
  df7_merge_plot_3 = df7_merge %>%
    filter(tag_sample == "阴性参考品" & str_detect(patho_namezn, "人内参"))
  df7_merge_plot_3$log_RPK = log10(df7_merge_plot_3$总人内参RPK+1)
  
  if (nrow(df7_merge_plot_3) > 0 && !all(is.na(df7_merge_plot_3$tag2)) && any(df7_merge_plot_3$date == args$date, na.rm = TRUE)) {
    dates = tail(unique(df7_merge_plot_3$date), n = 20)
    ordered_dates <- dates[order(as.Date(dates, format = "%y%m%d"))]
    
    retro_p3 =
      ggplot(df7_merge_plot_3, aes(date, log_RPK)) + 
      geom_point(aes(color = tag2,shape=QC_flag),size = 0.6) + 
      scale_shape_manual(values = c("质控合格" = 20, "质控不合格" = 0))+
      scale_color_manual(values = c("LY-new" = "blue", "DJ-new" = "red","LY-old" = "#66CCFF","DJ-old" = "#FF9933")) +
      facet_wrap(~ 体系, scales = "free") +
      theme_bw() + 
      scale_x_discrete(limits = rev(rev(ordered_dates))) +            ##设置X轴不超过60个时间点
      ggtitle(paste0(tixi_item,"-阴性参考品-","中总人内参的RPK分布及随时间的分布"))+
      theme(axis.text.x = element_text(angle = 90, hjust = 1),
            panel.grid = element_blank(),
            text = element_text(size = 8), 
            axis.text = element_text(size = 7), 
            axis.title = element_text(size = 6),
            plot.title = element_text(size = 8), 
            legend.text = element_text(size = 8), 
            legend.title = element_text(size = 8))
    all_retro_plot[[paste0("1-",tixi_item,"-阴性参考品-","总人内参RPK分布")]] <- retro_p3
  }
}
#######################################



###绘制目标病原RPK分布图；分体系 
######################################
all_retro_plot2 <- list()
for (i in 1:tixi_n){
  tixi_item = tixi[i]
  df7_merge = df7_merge_orgin %>% filter(体系 == tixi_item)
  df7_merge$log_RPK_value = log10(df7_merge$patho_RPK+1)
  df7_merge = df7_merge %>% 
    mutate(tag2 = case_when(
      grepl("LY",sample) & grepl(paste(args$date),date)~ "LY-new",
      grepl("DJ",sample) & grepl(paste(args$date),date)~ "DJ-new",
      grepl("LY",sample) & !grepl(paste(args$date),date)~ "LY-old",
      grepl("DJ",sample) & !grepl(paste(args$date),date)~ "DJ-old",
      TRUE ~ NA_character_,))
  
  tag_smaple_type = c("阳性参考品","阴性参考品","检测限参考品","重复性参考品","阳性对照品","阴性对照品")
  n = length(tag_smaple_type)
  for (j in 1:n){
    item = tag_smaple_type[j]
    
    df7_merge_plot2 = df7_merge %>% 
      filter(tag_sample == item,!str_detect(patho_namezn, "三叶草") & 
               !str_detect(patho_namezn, "外源内参") & !str_detect(patho_namezn,"人内参"))
    
    if (nrow(df7_merge_plot2) > 0  && !all(is.na(df7_merge_plot2$tag2)) && any(df7_merge_plot2$date == args$date, na.rm = TRUE)) {
      df7_merge_plot2 = df7_merge_plot2 %>% 
        group_by(tag) %>% 
        filter(!all(is.na(tag2))) %>% ungroup()
      
      # dates <- unique(df7_merge_plot2$date)[1:min(20, length(unique(df7_merge_plot2$date)))]
      dates = tail(unique(df7_merge_plot2$date), n = 20)
      ordered_dates <- dates[order(as.Date(dates, format = "%y%m%d"))]
      
      retro_p2 = 
        ggplot(df7_merge_plot2,aes(date,log_RPK_value)) + geom_point(aes(color = tag2,shape=QC_flag))+ 
        scale_shape_manual(values = c("质控合格" = 20, "质控不合格" = 0))+
        scale_color_manual(values = c("LY-new" = "blue", "DJ-new" = "red","LY-old" = "#66CCFF","DJ-old" = "#FF9933")) +
        facet_wrap(~ tag ,scales = "free")+ theme_bw()+
        scale_x_discrete(limits = rev(rev(ordered_dates))) +            ##设置X轴不超过60个时间点
        ggtitle(paste0(tixi_item,"-",item,"的目标病原RPK在各个体系的分布以及随时间的分布"))+
        theme(axis.text.x = element_text(angle = 90, hjust = 1),
              panel.grid = element_blank(),
              axis.text = element_text(size = 7))
      all_retro_plot2[[paste0("2-",tixi_item,"-",item,"-","目标病原RPK")]] <- retro_p2
    }
  }
}


multi_page_plots <- marrangeGrob(all_retro_plot, nrow = 2, ncol = 2,as.table=TRUE)
pdf(args$Retropdf, onefile = TRUE, width = 8, height = 8, family = "GB1")
print(multi_page_plots)
print(all_retro_plot2)
dev.off()
################################################################################



# 删除目录
unlink(output_dir, recursive = TRUE)
# 创建一个空的succeed.log文件
file.create(paste0(args$input_run,"/02.Macro/05.QA/pre-succeed.log"))

