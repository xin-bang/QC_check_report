#本流程目前仅适用于T2P2、T2P3、T3P3、T11A、T11B的流程质控分析；如添加新的体系，需要结合新体系的判断条件编写相应的判断模块
#其中回顾性统计仅针对T2P2、T3P2;回顾性绘图中也仅针对DJ，LY标准
#!/usr/bin/env Rscript

# 加载packages ------------------------------------------------------
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
})



# 导入输入文件 ------------------------------------------------------------------
# args <- list(
#   input_run = ".",
#   input0 = "./00_raw_data/Patho_report_final_format.addt5.project.sort.zip",
#   input1 = "./00_raw_data/QC_report_for_experiment.addt5.xls.zip",
#   input2 = "./00_raw_data/all_HP_vardect.txt.zip",
#   input3 = "./00_raw_data/Patho_report_final_format.trim.rptname.ntinfo.addsemi.zip",
#   input4 = "./00_raw_data/all.drug_mp.txt",
#   input5 = "./00_raw_data/V1.4-历史质检表.xlsx",
#   output1 = "./Test_QC_result.xlsx",
#   input6 = "./current_history_results.xlsx",
#   input7 = "./00_raw_data/config.xlsx",
#   input8 = "./00_raw_data/SampleSheetUsed.csv",
#   date = "241022",
#   output2 = "./current_history_results_thistime.xlsx",
#   comparepdf = "Test_QC_compare.pdf",
#   Retropdf = "Test_QC_retro.pdf"
# )


##各输入文件说明：
#Patho_report_final_format.addt5.project.sort.zip：                             //前台病原总表，汇总表检出病原
#QC_report_for_experiment.addt5.xls.zip：                                       //质控信息，汇总表样本质控情况
#all_HP_vardect.txt.zip：                                                       //提供耐药信息（百日咳耐药）
#all.drug_mp.txt：                                                              //提供耐药信息（肺炎支原体耐药）
#Patho_report_final_format.trim.rptname.ntinfo.addsemi.zip：                    //提供肺支和百日咳耐药RPK以及T2P3体系的其余耐药信息
#质控上机信息模板表：                                                           //由质量部同事填写，仅需要填写“表1-基本信息表”和“表2-对比信息表”，需要核查填写是否规范
#current_history_results.xlsx ：                                                //回顾性信息表，记录质检历史轮次的质检结果，本轮质检结果会同步到该该记录表哄着你
#config.xlsx：                                                                  //配置文件：
#SampleSheetUsed.csv文件：                                                      //用于核对本轮质检样本数和上机样本数是否一致


# # # 参数定义：
parser <- ArgumentParser(description="用于质控信息数据分析，目前仅针对T2P2、T3P3、T3P2以及T11中的企参和临床样本；其余类型样本无法分析")
parser$add_argument("--input_run", help="输入待分析run的path")
parser$add_argument("--input0", help="输入Patho_report_final_format.addt5.project.sort.zip")
parser$add_argument("--input1", help="输入QC_report_for_experiment.addt5.xls.zip")
parser$add_argument("--input2", help="输入all_HP_vardect.txt.zip")
parser$add_argument("--input3", help="输入Patho_report_final_format.trim.rptname.ntinfo.addsemi.zip")
parser$add_argument("--input4", help="输入all.drug_mp.txt")
parser$add_argument("--input5", help="输入质控上机信息模板表,注意需要核对样本名是否规范！！！")
parser$add_argument("--input6", help="输入回顾性信息表")
parser$add_argument("--input7", help="输入配置文件")
parser$add_argument("--input8",help = "输入SampleSheetUsed.csv文件")

parser$add_argument("--date", nargs='?', type="character", help="回顾性中指定日期，格式如240306")

parser$add_argument("--output1", help="质控信息分析结果表名称")
parser$add_argument("--output2", help="纳入本轮质控分析结果的回顾性表名称")
parser$add_argument("--comparepdf", help="输出对比分析的pdf")
parser$add_argument("--Retropdf", help="输出回顾性分析的pdf")
args <- parser$parse_args()     # 解析参数



##定义要解压的文件和目标文件夹 ---------------------------------------------------------
zip_file0 <- args$input0
zip_file1 <- args$input1
zip_file2 <- args$input2
zip_file3 <- args$input3
zip_file4 <- args$input4




##定义函数：检查和删除文件或文件夹 -------------------------------------------------------
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

# 检查并删除文件：01_supplement_info_unzip、succeed.log、error.log
output_dir <- paste0(args$input_run,"/01_supplement_info_unzip")
check_and_delete(output_dir)
check_and_delete(paste0(args$input_run, "/02.Macro/05.QA/succeed.log"))
check_and_delete(paste0(args$input_run, "/02.Macro/05.QA/error.log"))



##定义函数：对zip进行解压 ----------------------------------------------------------
system_unzip <- function(zip_file, output_dir, password) {
  if (Sys.info()["sysname"] == "Linux") {
    command <- sprintf("unzip -P %s '%s' -d '%s'", password, zip_file, output_dir)  #linux 系统
  } else if (Sys.info()["sysname"] == "Windows") {
    command <- sprintf("wsl unzip -P %s '%s' -d '%s'", password, zip_file, output_dir)  #win 系统
  } else {
    stop("Unsupported operating system.")
  }
  system(command)
}

#对文件进行解压缩
for (zip_file in list(zip_file0, zip_file1, zip_file2, zip_file3, zip_file4)) {
  file_name <- basename(zip_file)
  extension <- tools::file_ext(file_name)
  if (extension %in% c("zip")) {
    system_unzip(zip_file, output_dir, "kctngs2023")
  } else {
    file.copy(zip_file, file.path(output_dir, file_name))
  }
}






##读取后台病原及质控信息 ------------------------------------------------------------
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


##数据清洗整理
df1 <- df1 %>% full_join(df2, by = c("实验号" = "实验号"))
df1$date <- sapply(lapply(strsplit(df1$RUN, "_"),trimws),function(x) x[1])
df1$体系 <- sapply(lapply(strsplit(as.character(df1$实验号), "-"), trimws),function(x) x[1])
df1 <- df1 %>% rename(sample = 实验号,run=RUN,patho_namezn = 病原体,patho_reads =有效病原数据量,patho_RPK = 归一化reads数,filter_flag = 预判结果)
df1$temp_id  = sapply(strsplit(df1$sample, "-"), function(x) {if (length(x) > 2) { paste(x[1:2], collapse = "-")} else { paste(x, collapse = "-")}})






## 读取质检上机信息表 ---------------------------------------------------------------
df3 = read.xlsx(args$input5,sheet = "表1-基本信息表") 
colnames(df3) = df3[1, ]
df3 = df3[-1, ] %>% filter(!is.na(文库类型)) %>% filter(!is.na(文库编号))



##核对质检上机信息表是否规范
check_columns <- function(df, columns) {
  missing_columns <- setdiff(columns, names(df))
  if (length(missing_columns) > 0) {
    stop(paste("数据框缺少以下列:", paste(missing_columns, collapse = ", ")))
  }}
tryCatch({
  check_columns(df3, c("文库编号", "生产批号", "产品检类别","成品对应中间品批号",
                       "生产工艺","核酸提取日期","核酸重复次数","提取重复次数",
                       "文库浓度","Pooling体积","提取试剂规格","提取试剂批号",
                       "文库类型","企参编号"))
  }, error = function(e){print(paste("错误:", e$message))})
df1 <- df1 %>%full_join(df3, by = c("sample" = "文库编号"))   ##有一些在project sort中会被过滤的
df1$体系 = str_split(df1$sample, "-", simplify = TRUE)[, 1]




# 其余信息 --------------------------------------------------------------------
##20240511修订：增加样本核对功能：核对质检上机表的样本是否和SampleSheet的样本一致
sample_sheet = readLines(args$input8)
skip_line = grep("^\\[Data\\]", sample_sheet, value = FALSE)[1]
df_samplesheet = read.csv(args$input8,header = TRUE,skip= skip_line)

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



##核对质控SampleID是否规范:通过核对文库类型是否为空来判断
is_empty <- function(x) {return(is.na(x) | x == "")}
#设置options，使警告被视为错误
options(warn=2)                                                                 
check_condition <- function(df, column_name, condition_function) {
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









# 文件汇总处理 ------------------------------------------------------------------
## 按照企参编号匹配型别（目标病原） --------------------------------------------------------
## 需要根据体系及企参编号匹配对应的企参病原
df3_add_patho = read.xlsx(args$input5,sheet = "企参列表") %>% select("体系编号","编号","型别") %>% distinct()
df1 = df1 %>% mutate(企参编号 = case_when(is.na(企参编号) ~ "", TRUE ~ 企参编号))
df1 = df1 %>% left_join(df3_add_patho, by = c("体系" = "体系编号","企参编号" = "编号"),relationship = "many-to-many")
df1 = df1 %>% rename("tag_sample" = "文库类型","tag" = "temp_id") %>% filter(tag_sample != "")
df1 = df1 %>% mutate(型别 = case_when(tag_sample == "其它" ~ NA,TRUE ~ 型别)) %>% distinct()

df4 = df1 %>% filter(!is.na(tag_sample))
df4 = lapply(df4,as.character) %>% as_tibble()
df4$patho_RPK = as.numeric(df4$patho_RPK)


##对整合企参信息之后的DF进行数据清洗
#20240529：枯草和三叶草的名称问题修改；patho_namezn2是原名称；patho_namezn是规范后的名称；后续的分析都是用规范后的名称：patho_namezn
#名称修改的对应关系见config.xlsx；patho_name_fix
df4$patho_namezn2 = df4$patho_namezn
patho_name_fix = read.xlsx(args$input7,sheet = "patho_name_fix")
for (i in 1:nrow(patho_name_fix)) {
  df4 = df4 %>% mutate(patho_namezn = case_when(
      grepl(patho_name_fix$Original_name[i], patho_namezn) ~ patho_name_fix$replacement[i],
      TRUE ~ patho_namezn
    ))
}

#1:删除型别为“百日咳鲍特菌”的同时有“霍姆鲍特菌”检出情况；删除百日咳的耐药结果
df4 = df4 %>% filter(!(型别 == "百日咳鲍特菌" & patho_namezn == "霍姆鲍特菌") | is.na(型别) | is.na(patho_namezn))
df4 = df4 %>% filter(!str_detect(patho_namezn, "百日咳耐药__ptxP") | is.na(patho_namezn))



## 添加耐药信息 ------------------------------------------------------------------
#Sheet1:/02.Macro/03.HPVarDect/all_HP_vardect.txt.zip + 04.Drug_MP/all.drug_mp.txt：      
#Sheet2:/02.Macro/02.Statistic/Patho_report_final_format.trim.rptname.ntinfo.addsemi.zip   解压密码：kctngs2023
#all_HP_vardect.txt：百日咳鲍特菌耐药信息；all.drug_mp：肺炎支原体耐药信息；ntinfo.addsemi：耐药RPK
drug1 = read.table(paste0(output_dir,"/all.drug_mp.txt"), sep = "\t",  quote = "\"",header = TRUE, comment.char = "") %>% as_tibble()
drug2 = read.table(paste0(output_dir,"/all_HP_vardect.txt"), sep = "\t",  quote = "\"",header = TRUE, comment.char = "") %>% as_tibble()
all_patho = read.table(paste0(output_dir,"/Patho_report_final_format.trim.rptname.ntinfo.addsemi"),sep = "\t", quote = "\"",header = TRUE,comment.char = "") %>% as_tibble()
drug1 = drug1 %>% mutate_at(vars(resis_RawDep,resis_rpk),~suppressWarnings(as.numeric(.)))
drug2 = drug2 %>% mutate_at(vars(resis_RawDep,resis_rpk),~suppressWarnings(as.numeric(.)))


if (nrow(drug1) == 0 && nrow(drug2) == 0) {
  df_drug1 = drug1
} else if (nrow(drug1) == 0) {
  df_drug1 = drug2  
} else if (nrow(drug2) == 0) {
  df_drug1 = drug1 
} else {
  df_drug1 = full_join(drug1,drug2)
}

df_drug2 = all_patho
df_drug2 = all_patho %>% mutate(patho_namezn =case_when(
  grepl("百日咳大环内酯耐药__23S__BP",patho_namezn)  ~ "百日咳鲍特菌耐药",
  TRUE ~ patho_namezn
))


df_drug1 =df_drug1 %>% select(run,sample,resis_name,resis_MutLog,resis_rpk)
df_drug2$耐药名称 = sapply(lapply(strsplit(as.character(df_drug2$patho_namezn), "_"), trimws), function(x) x[1])
df_drug2 =df_drug2 %>% select(run,sample,耐药名称,patho_RPK)
df_drug1 = df_drug1 %>% left_join(df_drug2,by=c("sample" = "sample","resis_name" = "耐药名称","run" = "run")) 

#百日耐药：只从all_HP_vardect.txt.zip 提取RPK
df_drug1 = df_drug1 %>% filter(resis_rpk != "-")
df_drug1 = df_drug1 %>% mutate(patho_RPK = case_when(resis_name == "百日咳鲍特菌耐药" ~ resis_rpk,TRUE ~ patho_RPK))

df_drug1 = df_drug1 %>% filter(resis_MutLog != "不适用") %>% 
  unite("drug_info",resis_name,resis_MutLog,patho_RPK,sep ="|",remove = FALSE) %>% 
  select(-patho_RPK,-resis_rpk) %>% distinct()


##20240929修订：针对T2P3体系添加所有的耐药数据,汇总到df_drug1中
df_drug3 = all_patho %>% filter(str_detect(sample,"T2P3") & str_detect(patho_namezn,"耐药")) %>%
  select(run,sample,patho_namezn,patho_RPK,filter_flag) %>% distinct()
if (nrow(df_drug3) > 0) {
  df_drug3$耐药名称 = sapply(
    lapply(strsplit(as.character(df_drug3$patho_namezn), "_"), trimws), function(x) x[1])
  df_drug3 = df_drug3 %>% distinct() %>% unite("drug_info",耐药名称,filter_flag,patho_RPK,sep ="|",remove = FALSE) %>% 
    select(-c(patho_namezn,patho_RPK)) %>% rename("resis_name" = "耐药名称","resis_MutLog" = "filter_flag") %>% distinct()
  df_drug1 = bind_rows(df_drug1,df_drug3)
  # df_drug1 = df_drug1 %>% select(-run)
} else {
  print("本轮实验中没有T2P3体系")
}

df4 <- df4 %>% left_join(df_drug1, by = c("sample" = "sample"),relationship = "many-to-many")
df4 = df4 %>% select(-run.y) %>% rename("run" = "run.x")






# 企参样本分析 ------------------------------------------------------------------
# 20240722：需要保留NTC，NEG样本及其patho（tag_sample)
# 20241025：删除人副流感病毒以及一些病原子型
df5 = df4 %>% filter(!is.na(tag_sample))
df5 = df5 %>% filter((tag_sample %in% c("NTC","NEG")) | (!patho_namezn %in% c("肠道病毒","肠道病毒A组","人腺病毒E组","人腺病毒C组","人腺病毒21型","人腺病毒B组","人腺病毒","人副流感病毒"))) 


#config.xslx : patho_class(args$input7)：将病原分为：目标病原、外源病原、外源内参、人内参等
patho_class <- read.xlsx(args$input7,sheet = "patho_class") 
df5$patho_tag = "外源病原"    #默认都是外源病原，如果需要添加，请在配置文件中调整
for (i in 1:nrow(patho_class)) {
  df5 <- df5 %>%
    mutate(patho_tag = case_when(
      grepl(patho_class$condition[i], patho_namezn) & grepl(patho_class$tag[i], tag) ~ patho_class$label[i],
      grepl(patho_class$condition[i], patho_namezn) & grepl(patho_class$tag[i], 体系) ~ patho_class$label[i],
      TRUE ~ patho_tag
    ))
}

df5 = df5 %>% mutate(patho_tag = case_when(is.na(patho_namezn) ~ "未检出病原",TRUE ~ patho_tag))

#汇总统计表 -----------------------------------------------------------------
df5_cc<- df5 %>%
  mutate(patho_tag2 = case_when(
    grepl("外源病原", patho_tag) ~ paste0(patho_namezn, "|", filter_flag,"|",as.character(patho_RPK)),
    grepl("耐药/毒力基因",patho_tag) ~ paste0(patho_namezn,"|",filter_flag,"|",as.character(patho_RPK)),
    TRUE ~ as.character(patho_RPK) ##条件没有满足，则为原来的数字
  ))

df5_cc_temp = df5_cc %>% filter(patho_tag == "目标病原") %>% select(run,sample,型别,filter_flag,patho_namezn) %>% distinct()
df5_cc = df5_cc %>% select(
  run,date,sample,体系,tag,tag_sample,型别,原始数据,
  有效数据比例,Q30,patho_tag,patho_tag2,resis_MutLog,
  drug_info,生产批号,产品检类别,成品对应中间品批号,
  生产工艺,核酸提取日期,核酸重复次数,提取重复次数,
  文库浓度,Pooling体积) %>%distinct()

#20240716:warning可能出现的目标病原为空的情况
if (nrow(df5_cc_temp) == 0) {
  warning(paste("目标病原记录为空，请检查实验号是否记录错误"))
}

df5_cc_stat = df5_cc %>% pivot_wider(names_from = patho_tag, values_from = patho_tag2,values_fn = ~paste(.,collapse = ";"))  
df5_cc_stat = df5_cc_stat %>% mutate("外源病原" = case_when("外源病原" %in% colnames(df5_cc_stat)~ 外源病原,TRUE ~ "NA"))
if (!"耐药/毒力基因" %in% colnames(df5_cc_stat)) {
  df5_cc_stat$`耐药/毒力基因` = ""
}
df5_cc_stat = df5_cc_stat %>% mutate("耐药/毒力基因" = case_when("耐药/毒力基因" %in% colnames(df5_cc_stat)~ `耐药/毒力基因`,TRUE ~ "NA"))

##规范耐药信息列:不适用的直接为空值(drug_info)
df5_cc_stat = df5_cc_stat %>% mutate(drug_info = case_when(grepl("不适用",resis_MutLog) ~ " ", TRUE ~ drug_info))
df5_cc_stat= df5_cc_stat %>% left_join(df5_cc_temp, by = c("run" = "run","sample" = "sample", "型别" = "型别")) 
df5_cc_stat = df5_cc_stat %>% pivot_wider(names_from = resis_MutLog, values_from = drug_info,values_fn = list)  

##结果敏感和耐药交替出现的情况
if ("耐药" %in% names(df5_cc_stat) & "敏感" %in% names(df5_cc_stat)) {
  df5_cc_stat = df5_cc_stat %>% unite("resis_info",耐药,敏感,sep =";",remove = TRUE)
  df5_cc_stat$resis_info = gsub("(NULL;)|(;NULL)|(NULL)","",df5_cc_stat$resis_info)
  } else if ("耐药" %in% names(df5_cc_stat) & !("敏感" %in% names(df5_cc_stat))){
    df5_cc_stat = df5_cc_stat %>% rename(resis_info = 耐药)
    } else if ("敏感" %in% names(df5_cc_stat) & !("耐药" %in% names(df5_cc_stat))){
      df5_cc_stat = df5_cc_stat %>% rename(resis_info = 敏感)
      } else if (!("敏感" %in% names(df5_cc_stat)) & !("耐药" %in% names(df5_cc_stat))){
        df5_cc_stat = df5_cc_stat %>% rename(resis_info = "NA")
        }


# 20240716：使用trycatch捕获由于无企参样本而造成缺失目标病原造成报错的情况
df5_cc_stat = tryCatch({
    df5_cc_stat = df5_cc_stat %>% 
      rename("目标病原" = "型别","其它病原" = "外源病原","目标病原RPK" = "目标病原","目标病原预判" = "filter_flag") %>%
      select(run,date,sample,体系,tag,tag_sample,原始数据,Q30,有效数据比例,目标病原,目标病原RPK,目标病原预判,
             contains("内参"),其它病原,resis_info,`耐药/毒力基因`,patho_namezn,生产批号,产品检类别,成品对应中间品批号,
             生产工艺,核酸提取日期,核酸重复次数,提取重复次数,文库浓度,Pooling体积)
    },error = function(e){
      cat("Warings：本轮质检无目标病原\n")
      df5_cc_stat$目标病原 <- "NA"
      df5_cc_stat = df5_cc_stat %>% 
        rename("目标病原" = "型别","其它病原" = "外源病原","目标病原RPK" = "目标病原","目标病原预判" = "filter_flag") %>% 
        select(run,date,sample,体系,tag,tag_sample,原始数据,Q30,有效数据比例,目标病原,目标病原RPK,目标病原预判,
               contains("内参"),其它病原,resis_info,`耐药/毒力基因`,patho_namezn,生产批号,产品检类别,成品对应中间品批号,
               生产工艺,核酸提取日期,核酸重复次数,提取重复次数,文库浓度,Pooling体积)
    })



df5_cc_stat$目标病原 = gsub("Jurkat细胞沉淀|无核酸酶水","",df5_cc_stat$目标病原)
df5_cc_stat$其它病原 = gsub("(未检出相关病原体|NA|NA;)|(未检出相关病原体|NA|NA)","",df5_cc_stat$其它病原,fixed = TRUE)
df5_cc_qc = df1 %>% select(sample,质控评价) %>% distinct() #添加质控评价信息
df5_cc_stat = df5_cc_stat %>% left_join(df5_cc_qc,by = c("sample" = "sample"))

##将人内参ZXF，人内参ACTB，人内参XXX全部相加
list_columns <- sapply(df5_cc_stat, is.list)
df5_cc_stat[, list_columns] <- lapply(df5_cc_stat[, list_columns], function(x) sapply(x, function(y) paste(y, collapse = ";")))
df5_cc_stat <- df5_cc_stat %>%
  mutate(总人内参 = rowSums(select(., contains("人内参")) %>% mutate_all(as.numeric), na.rm = TRUE)) %>% 
  select(run,date,sample,体系,tag,tag_sample,原始数据,Q30,有效数据比例,目标病原,目标病原RPK,目标病原预判, matches("总人内参|外源内参"),
         其它病原,resis_info,`耐药/毒力基因`,质控评价,patho_namezn,生产批号,产品检类别,成品对应中间品批号,生产工艺,核酸提取日期,核酸重复次数,
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
if (!("外源内参" %in% names(df5_cc_stat))){df5_cc_stat$外源内参 = 0} else {df5_cc_stat$外源内参 = df5_cc_stat$外源内参}
if (!("总人内参" %in% names(df5_cc_stat))){df5_cc_stat$总人内参 = 0} else {df5_cc_stat$总人内参 = df5_cc_stat$总人内参}
if (!("目标病原RPK" %in% names(df5_cc_stat))){df5_cc_stat$目标病原RPK = 0} else {df5_cc_stat$目标病原RPK = df5_cc_stat$目标病原RPK}
df5_cc_stat <- df5_cc_stat %>% mutate_at(vars(原始数据, Q30,目标病原RPK,外源内参,总人内参), as.numeric)  
df5_cc_stat$resis_info = gsub("c\\(\"", "",df5_cc_stat$resis_info) 
df5_cc_stat$resis_info = gsub("\"\\)", "",df5_cc_stat$resis_info)
df5_cc_stat$resis_info = gsub("\", \"", ";",df5_cc_stat$resis_info)



## 添加最终评价 ------------------------------------------------------------------
# 替换 NA 值
df5_cc_stat <- df5_cc_stat %>%
  mutate(
    其它病原 = ifelse(其它病原 == "NA|NA|NA", NA, 其它病原),
    外源内参 = replace_na(外源内参, 0),
    总人内参 = replace_na(总人内参, 0),
    目标病原 = replace_na(目标病原, "")
  )

# 定义检查函数:检查耐药
check_resis_condition <- function(data, column, threshold) {
  sapply(strsplit(data[[column]], ";"), function(x) {
    values <- as.numeric(sapply(strsplit(x, "\\|"), `[`, 3))
    values[is.na(values)] <- 0
    all(values < threshold)   ##T2P2、T3P3小于500会被标记为TRUE；T2P3、T11小于300会被标记为TRUE；
  })
}

# 定义检查函数:检查其它病原
check_other_patho_condition <- function(data, column) {
  sapply(strsplit(data[[column]], ";"), function(x) {
    values <- sapply(strsplit(x, "\\|"), `[`, 2)
    values[is.na(values)] <- "滤"
    all(values == "滤")  ##其它病原中全部都是“滤”会被标记为TRUE
  })
}

# 中间变量存储检查结果:T2P2、T3P3小于500会被标记为TRUE；T2P3、T11小于300会被标记为TRUE；
df5_cc_stat <- df5_cc_stat %>%
  mutate(
    resis_info_check_1 = check_resis_condition(df5_cc_stat, "resis_info",500),
    resis_info_check_2 = check_resis_condition(df5_cc_stat, "resis_info",300),
    other_pathogen_check = check_other_patho_condition(df5_cc_stat, "其它病原")
  )



# 最终评价
# 由于一开始质量部制定的规则过于冗长，而且后期会可能添加其它体系，目前我能想到的最好的方法是case_when，如果用if嵌套，估计会很长
##20240929 针对目标病原是百日咳，但resis_info是空时的bug，判断修订为：(str_detect(resis_info, "百日咳|^$")
df5_cc_stat <- df5_cc_stat %>%
  mutate(
    最终评价 = case_when(
      
      tag_sample %in% c("临床样本", "其它") ~ 质控评价,
      
      #T2P3体系的判断
      体系 == "T2P3" & tag_sample == "NTC" & resis_info_check_2 & other_pathogen_check ~ "合格",
      体系 == "T2P3" & tag_sample == "阴性参考品" & resis_info_check_2 & other_pathogen_check & 总人内参 > 200 & (质控评价 == "合格") ~ "合格",
      体系 == "T2P3" & tag_sample == "阴性对照品" & resis_info_check_2 & other_pathogen_check & 外源内参 > 50 ~ "合格",
      体系 == "T2P3" & tag_sample == "阳性对照品" & resis_info_check_2 & other_pathogen_check & 外源内参 > 50 & 目标病原预判 != "滤" ~ "合格",
      体系 == "T2P3" & tag_sample %in% c("检测限参考品","阳性参考品","重复性参考品") & other_pathogen_check & (质控评价 == "合格") & 目标病原预判 != "滤" & 
        ((!str_detect(目标病原, "百日咳") & resis_info_check_2) | (str_detect(目标病原, "百日咳") & str_detect(resis_info, "百日咳|^$"))) ~ "合格",

      
      
      #20241010修订；①：感染1000没有加外源内参，人内参。对于外源内参 < 50 则判为合格；人内参 ≤ 200 则判为合格；②：T11体系不考虑质控评价列
      体系 %in% c("T11A","T11B") & tag_sample == "NTC" & resis_info_check_2 & other_pathogen_check ~ "合格",
      体系 %in% c("T11A","T11B") & tag_sample == "阴性参考品" & resis_info_check_2 & other_pathogen_check & 总人内参 <= 200  ~ "合格",
      体系 %in% c("T11A","T11B") & tag_sample == "阴性对照品" & resis_info_check_2 & other_pathogen_check & 外源内参 < 50 ~ "合格",
      体系 %in% c("T11A","T11B") & tag_sample == "阳性对照品" & resis_info_check_2 & other_pathogen_check & 外源内参 < 50 & 目标病原预判 != "滤" ~ "合格",
      体系 %in% c("T11A","T11B") & tag_sample %in% c("检测限参考品","阳性参考品","重复性参考品") & other_pathogen_check & 目标病原预判 != "滤" & 
        ((!str_detect(目标病原, "百日咳") & resis_info_check_2) | (str_detect(目标病原, "百日咳") & str_detect(resis_info, "百日咳|^$"))) ~ "合格",

      
      #其余体系的判断
      !体系 %in% c("T2P3","T11A","T11B") & tag_sample == "NTC" & resis_info_check_1 & other_pathogen_check ~ "合格",
      !体系 %in% c("T2P3","T11A","T11B") & tag_sample == "阴性参考品" & resis_info_check_1 & other_pathogen_check & 总人内参 > 200 ~ "合格",
      !体系 %in% c("T2P3","T11A","T11B") & tag_sample == "阴性对照品" & resis_info_check_1 & other_pathogen_check & 外源内参 > 50 ~ "合格",
      !体系 %in% c("T2P3","T11A","T11B") & tag_sample == "阳性对照品" & resis_info_check_1 & other_pathogen_check & 外源内参 > 50 & 目标病原预判 != "滤" ~ "合格",
      !体系 %in% c("T2P3","T11A","T11B") & tag_sample %in% c("检测限参考品","阳性参考品","重复性参考品") & other_pathogen_check & 外源内参 > 50 & 目标病原预判 != "滤" &
        ((!str_detect(目标病原, "百日咳") & resis_info_check_1) | (str_detect(目标病原, "百日咳") & str_detect(resis_info, "百日咳|^$")))~ "合格",
      
      
      TRUE ~ "不合格"
    )
  )


##新增判断1：对原始数据和Q30的判断
df5_cc_stat = df5_cc_stat %>% mutate(
  最终评价 = case_when(
    str_detect(最终评价,"不合格") ~ "不合格",
    原始数据 <= 50000 ~ "不合格",
    Q30 < 0.75 ~ "不合格",
    TRUE ~ 最终评价
  ))



##新增判断2：针对T2P2和T11体系的NEG（阴性对照品）、POS进行联立判断，规则：
#重复的3个样本中：检出非目标病原2个弱阳或1个阳性，或检出病原耐药RPK>300大于1个样本，或检出人内参RPK>50大于1个样本，认为不合格
#以上的联立分析不考虑对照（DZ）的POS和NEG
df5_cc_stat = df5_cc_stat %>% group_by(体系,生产批号,tag_sample) %>% 
  mutate(
    n_弱阳个数 = n_distinct(sample[str_detect(其它病原,"弱阳")]), 
    n_阳性个数 = n_distinct(sample[str_detect(其它病原,"\\|阳性\\|")]),
    n_耐药个数 = n_distinct(sample[str_detect(resis_info_check_2,"FALSE")]),
    n_内参个数 = n_distinct(sample[总人内参 > 50])
    ) %>% ungroup()

df5_cc_stat = df5_cc_stat %>% mutate(
  最终评价 = case_when(
    体系 %in%  c("T2P3","T11A","T11B") & tag_sample %in% c("阳性对照品","阴性对照品") & !str_detect(sample,"DZ") &  ##联立判断不考虑对照
      ((n_弱阳个数 > 2) | (n_阳性个数 > 1) | (n_耐药个数 > 1) | (n_内参个数 > 1)) ~ "不合格",
    TRUE ~ 最终评价
  ))



## 添加不合格原因 -----------------------------------------------------------------
df5_cc_stat <- df5_cc_stat %>%
  mutate(不合格原因 = case_when(
    
    ##临床及其余类型样本
    str_detect(最终评价,"不合格") & tag_sample %in% c("临床样本","其它") ~ 质控评价,

    ##企参样本：T2P3
    体系 == "T2P3" & str_detect(最终评价,"不合格") ~ paste(
      ifelse(tag_sample %in% c("NTC", "阳性参考品","检测限参考品","阴性参考品","阴性对照品","重复性参考品","阳性对照品") & (原始数据 <= 50000),"原始数据不合格",NA_character_),
      ifelse(tag_sample %in% c("NTC", "阳性参考品","检测限参考品","阴性参考品","阴性对照品","重复性参考品","阳性对照品") & (Q30 <= 0.75),"Q30不合格",NA_character_),
      
      ifelse(tag_sample %in% c("阳性参考品","重复性参考品","检测限参考品","阴性参考品") & str_detect(质控评价,"注意人内参低"),"内参不合格",NA_character_),
      ifelse(tag_sample %in% c("阳性参考品","重复性参考品","检测限参考品","阴性参考品") & other_pathogen_check== "FALSE","病原污染",NA_character_),
      ifelse(tag_sample %in% c("阳性参考品","重复性参考品","检测限参考品","阴性参考品") & resis_info_check_2== "FALSE","耐药污染",NA_character_),
      ifelse(tag_sample %in% c("阳性参考品","重复性参考品","检测限参考品") & (目标病原预判 == "滤" | is.na(目标病原预判)),"目标病原漏检",NA_character_),
      ifelse(tag_sample == "阴性参考品" & 总人内参 <= 200,"目标病原漏检",NA_character_),

      ifelse(tag_sample %in% c("阳性对照品","阴性对照品") & !str_detect(sample,"DZ") & (n_内参个数 > 1),"内参不合格",NA_character_),
      ifelse(tag_sample %in% c("阳性对照品","阴性对照品") & !str_detect(sample,"DZ") & ((n_弱阳个数 > 2) | (n_阳性个数 > 1)),"病原污染",NA_character_),
      ifelse(tag_sample %in% c("阳性对照品","阴性对照品") & !str_detect(sample,"DZ") & (n_耐药个数 > 1),"耐药污染",NA_character_),
      ifelse(tag_sample == "阳性对照品" & (目标病原预判 == "滤" | is.na(目标病原预判)),"内参不合格",NA_character_),
      sep = ";"
      ),
    
    
    ##企参样本：T11
    体系 %in% c("T11A","T11B") & str_detect(最终评价,"不合格") ~ paste(
      ifelse(tag_sample %in% c("NTC", "阳性参考品","检测限参考品","阴性参考品","阴性对照品","重复性参考品","阳性对照品") & (原始数据 <= 50000),"原始数据不合格",NA_character_),
      ifelse(tag_sample %in% c("NTC", "阳性参考品","检测限参考品","阴性参考品","阴性对照品","重复性参考品","阳性对照品") & (Q30 <= 0.75),"Q30不合格",NA_character_),
      
      ifelse(tag_sample %in% c("阳性参考品","重复性参考品","检测限参考品") & (目标病原预判 == "滤" | is.na(目标病原预判)),"目标病原漏检",NA_character_),
      ifelse(tag_sample %in% c("阳性参考品","重复性参考品","检测限参考品","阴性参考品") & other_pathogen_check== "FALSE","病原污染",NA_character_),
      ifelse(tag_sample %in% c("阳性参考品","重复性参考品","检测限参考品","阴性参考品") & resis_info_check_2== "FALSE","耐药污染",NA_character_),
      ifelse(tag_sample == "阴性参考品" & 总人内参 > 200,"内参不合格",NA_character_),
      
      ifelse(tag_sample %in% c("阳性对照品","阴性对照品") & (n_内参个数 > 1),"内参不合格",NA_character_),
      ifelse(tag_sample %in% c("阳性对照品","阴性对照品") & ((n_弱阳个数 > 2) | (n_阳性个数 > 1)),"病原污染",NA_character_),
      ifelse(tag_sample %in% c("阳性对照品","阴性对照品") & (n_耐药个数 > 1),"耐药污染",NA_character_),
      ifelse(tag_sample == "阳性对照品" & (目标病原预判 == "滤" | is.na(目标病原预判)),"目标病原漏检",NA_character_),
      sep = ";"
      ),
    

    ##企参样本：其余体系
    !体系 %in% c("T11A","T11B","T2P3") & str_detect(最终评价,"不合格") ~ paste(
      ifelse(tag_sample %in% c("NTC", "阳性参考品","检测限参考品","阴性参考品","阴性对照品","重复性参考品","阳性对照品") & (原始数据 <= 50000),"原始数据不合格",NA_character_),
      ifelse(tag_sample %in% c("NTC", "阳性参考品","检测限参考品","阴性参考品","阴性对照品","重复性参考品","阳性对照品") & (Q30 <= 0.75),"Q30不合格",NA_character_),
      ifelse(tag_sample %in% c("NTC", "阳性参考品","检测限参考品","阴性参考品","阴性对照品","重复性参考品","阳性对照品") & str_detect(其它病原, "阳"),"病原污染",NA_character_),
      ifelse(tag_sample %in% c("NTC", "阳性参考品","检测限参考品","阴性参考品","阴性对照品","重复性参考品","阳性对照品") & !resis_info_check_1, "耐药污染",NA_character_),
      
      ifelse(tag_sample %in% c("阳性参考品","检测限参考品","阴性对照品","重复性参考品","阳性对照品") & 外源内参 <= 50,"外源内参不合格",NA_character_),
      ifelse(tag_sample %in% c("阳性参考品","检测限参考品","重复性参考品","阳性对照品") & (目标病原预判 == "滤" | is.na(目标病原预判)),"目标病原漏检",NA_character_),
      sep = ";"
    ),
    TRUE ~ NA_character_
    )) 

df5_cc_stat <- df5_cc_stat %>%
  mutate(
    不合格原因 = str_remove_all(不合格原因, "\\bNA\\b"),          # 移除单独的 NA
    不合格原因 = str_replace_all(不合格原因, ";{2,}", ";"),      # 替换连续多个分号为单个分号
    不合格原因 = str_replace_all(不合格原因, "^;+|;+$", ""),      # 确保移除开头或结尾的连续分号
    不合格原因 = str_trim(不合格原因)                            # 移除首尾的隐藏字符（如空格、换行符等）
  )



df5_cc_stat = df5_cc_stat %>% select(-c("resis_info_check_1","resis_info_check_2","other_pathogen_check",matches(("n_"))))


# 20240509修改：针对甲流和甲流2009的情况处理：有2009就按2009 没有2009就按甲流
# 按照sample分组，检查是否同时存在"甲型"和"甲型2009"
df5_cc_stat <- df5_cc_stat %>%
  group_by(sample) %>%
  mutate(has_2009 = any(patho_namezn == "甲型流感病毒H1N1(2009)")) %>%
  mutate(has_2009 = replace_na(has_2009, FALSE)) %>% 
  filter(!(patho_namezn == "甲型流感病毒" & has_2009)) %>%
  select(-has_2009)

df5_cc_stat_final = df5_cc_stat %>% select(体系,生产批号,run,sample,tag_sample,有效数据比例,最终评价,不合格原因) %>% rename("RUN" = "run","实验编号" = "sample","文库编号" = "tag_sample") %>% as_tibble()




# 各病原污染情况评估 -----------------------------------------------------------------
# df5_cc_other_patho_final
df5_cc_other_patho = df5 %>% filter(tag_sample %in% c("NTC","检测限参考品","阳性参考品","阴性参考品","阴性对照品","阳性对照品","重复性参考品")) %>% filter(!is.na(tag_sample)) 

if (nrow(df5_cc_other_patho) > 0){
  df5_cc_other_patho <- df5_cc_other_patho %>%
    group_by(体系,生产批号) %>%
    mutate(same_batch_num = n_distinct(sample)) %>% ungroup()
  
  df5_cc_other_patho =
    df5_cc_other_patho%>% group_by(体系,生产批号,same_batch_num,patho_tag,patho_namezn) %>% 
    summarise(total_sample = n_distinct(sample),
              RPK_median = median(patho_RPK,na.rm = TRUE),
              RPK_mean = round(mean(patho_RPK, na.rm = TRUE), digits = 1),
              .groups = "drop") %>% 
    filter(patho_tag == "外源病原") %>% 
    mutate(sample_frequency = total_sample / same_batch_num) %>% ungroup() %>% 
    select(-patho_tag)
  } else {
    print("本轮质检没有企参、NTC、NEG相关样本，请确认")
    df5_cc_other_patho = as.data.frame(matrix(NA,ncol = 5, nrow = 1))
    colnames(df5_cc_other_patho) <- c("same_batch_num", "patho_namezn", "total_sample", "RPK_median", "sample_frequency")
    }

##添加百日咳和肺炎耐药的信息：
df5_cc_other_patho_2 = df5 %>% filter(tag_sample %in% c("NTC","检测限参考品","阳性参考品","阴性参考品","阴性对照品","阳性对照品","重复性参考品")) %>% filter(!is.na(tag_sample))
df5_cc_other_patho_2 = df5_cc_other_patho_2 %>% filter(!(型别 %in% c("百日咳鲍特菌","肺炎支原体"))) %>% filter(!is.na(drug_info))


if(nrow(df5_cc_other_patho_2) > 0){
  df5_cc_other_patho_2 = df5_cc_other_patho_2 %>% 
    group_by(体系,生产批号) %>% mutate(same_batch_num = n_distinct(sample)) %>% ungroup()
  
  df5_cc_other_patho_2 = df5_cc_other_patho_2 %>% 
    separate(drug_info, sep = "\\|", c("patho","drug","RPK"), remove = TRUE) %>%
    select(体系,sample, 生产批号,patho, RPK,same_batch_num) %>% 
    distinct() %>% 
    group_by(体系,生产批号,same_batch_num,patho) %>% 
    summarise(total_sample = n(),
              RPK_median = median(as.numeric(RPK), na.rm = TRUE),
              RPK_mean = round(mean(as.numeric(RPK), na.rm = TRUE), digits = 1),
              .groups = "drop") %>% 
    mutate(sample_frequency = total_sample / same_batch_num)
  
  df5_cc_other_patho_2$RPK_median = as.numeric(df5_cc_other_patho_2$RPK_median) 
  df5_cc_other_patho_2$RPK_mean = as.numeric(df5_cc_other_patho_2$RPK_mean)
  df5_cc_other_patho_2 = df5_cc_other_patho_2 %>% rename("patho_namezn" = "patho") %>% ungroup()
  } else {
    print("本轮之间无无百日咳和肺炎耐药检出（耐药信息为空）")
    }


if(nrow(df5_cc_other_patho_2) > 0 & nrow(df5_cc_other_patho) > 0){
  df5_cc_other_patho =df5_cc_other_patho %>%  full_join(df5_cc_other_patho_2)
  } else if (nrow(df5_cc_other_patho_2) > 0 & nrow(df5_cc_other_patho) == 0) {
    df5_cc_other_patho = df5_cc_other_patho2
    } else if (nrow(df5_cc_other_patho_2) == 0 & nrow(df5_cc_other_patho) > 0){
      df5_cc_other_patho = df5_cc_other_patho
      }


## 添加生信预判 ----------------------------------------------------------------

#标准如下：
#添加T2P3生信预判:标准如下：20240909修订：
#非T2P3和T11A体系 不合格：PK_median > 20  & ratio > 0.5；而对于百日咳耐药的，调整其不合格阈值：RPK median > 500 
#T2P3体系 不合格: 
#1：非目标病原且非常见背景病原 ratio > 0.4 & total_sample > 2 ; 
#2：非目标病原且非常见背景病原 的关联耐药 ratio > 0.5 且 RPK_median > 300;
#3：对于常见背景病原 ratio > 0.5 且 RPK_median > 20；

#添加T11A生信预判:标准如下：20241009修订：
#非T2P3和T11A体系 不合格：PK_median > 20  & ratio > 0.5；而对于百日咳耐药的，调整其不合格阈值：RPK median > 500 
#T11A体系 不合格: 
#1：非目标病原且非常见背景病原 ratio > 0.5 & total_sample > 2 ; 
#2：对于常见背景病原 ratio > 0.5 且 RPK_mean > 50；

Common_patho_T2P3 = c("嗜麦芽窄食单胞菌|洋葱伯克霍尔德菌复合群|阴沟肠杆菌复合群|大肠埃希菌|镰刀菌属|铜绿假单胞菌")
Common_patho_TA11 = c("嗜麦芽窄食单胞菌|洋葱伯克霍尔德菌复合群|人葡萄球菌|表皮葡萄球菌|季也蒙毕赤酵母|嗜水气单胞菌|耳念珠菌|黏质沙雷菌|咽峡炎链球菌")

if(nrow(df5_cc_other_patho) > 0){
  df5_cc_other_patho = df5_cc_other_patho %>% 
    mutate(生信预判 = case_when(
      !体系 %in% c("T2P3","T11A","T11B") & !str_detect(patho_namezn,"百日咳") & sample_frequency > 0.5 & RPK_median > 20 ~ "不合格",
      !体系 %in% c("T2P3","T11A","T11B") & str_detect(patho_namezn,"百日咳") & sample_frequency > 0.5 & RPK_median > 500 ~ "不合格",
      
      体系== "T2P3" & !str_detect(patho_namezn,Common_patho_T2P3) & !str_detect(patho_namezn,"百日咳") & sample_frequency > 0.4 & total_sample > 2 ~ "不合格",
      体系== "T2P3" & !str_detect(patho_namezn,Common_patho_T2P3) & str_detect(patho_namezn,"百日咳") & sample_frequency > 0.5 & RPK_median > 300 ~ "不合格",
      体系== "T2P3" & str_detect(patho_namezn,Common_patho_T2P3) & sample_frequency > 0.5 & RPK_median > 20 ~ "不合格",
      
      体系 %in% c("T11A","T11B") & !str_detect(patho_namezn,Common_patho_TA11)& !str_detect(patho_namezn,"百日咳") & sample_frequency > 0.5 & total_sample > 2 ~ "不合格",
      体系 %in% c("T11A","T11B") & str_detect(patho_namezn,Common_patho_TA11) & sample_frequency > 0.5 & RPK_mean > 50 ~ "不合格",
      
      TRUE ~ "合格"
    ))
}

#20240510修改：污染病原为空的，删除掉该行
df5_cc_other_patho = df5_cc_other_patho %>% filter(!is.na(patho_namezn))




# 病原效率对比 ---------------------------------------------------------------
# 识别质检模板.xlsx中的 "表2-对比信息表"；输出 df5_all_compare; df6_stat
sample_compare_df = read.xlsx(args$input5,sheet = "表2-对比信息表") #核对名称是否规范
sample_compare_df = sample_compare_df %>% filter(!is.na(`待检试剂-对应文库`) & !is.na(`留样试剂-对应文库`))

if (nrow(sample_compare_df) > 0){
  sample_compare_df = sample_compare_df %>% 
    mutate(Group = row_number(),con_DJ = "DJ",con_LY = "LY") %>% 
    rename("sample_DJ" = "待检试剂-对应文库","sample_LY" = "留样试剂-对应文库") %>% 
    select(Group,sample_DJ,con_DJ,sample_LY,con_LY)
  
  # 使用tryCatch()来捕获可能的缺列错误
  tryCatch({
    check_columns(sample_compare_df, c("Group","sample_DJ","con_DJ","sample_LY","con_LY"))
  }, error = function(e) {
    print(paste("错误:", e$message))
  })
  

  ## QC对比 --------------------------------------------------------------------
  ##仅对企参样本进行分析:df6_stat
  df6_1 <- left_join(sample_compare_df, df5_cc_stat, by = c("sample_DJ" = "sample")) %>% select(-c(date,目标病原预判,其它病原))
  df6_2 <- left_join(df6_1, df5_cc_stat, by = c("sample_LY" = "sample"),suffix=c("_DJ","_LY")) %>% select(-c(date,目标病原预判,其它病原))
  df6_stat = df6_2 %>% select(
    run_DJ,体系_DJ,tag_DJ,tag_sample_DJ,目标病原_DJ,sample_DJ,
    sample_LY,原始数据_DJ,原始数据_LY,Q30_DJ,Q30_LY,有效数据比例_DJ,
    有效数据比例_LY,目标病原RPK_DJ,目标病原RPK_LY,外源内参_DJ,
    外源内参_LY,总人内参_DJ,总人内参_LY,resis_info_DJ,resis_info_LY,
    质控评价_DJ,质控评价_LY,生产批号_DJ,生产批号_LY,文库浓度_DJ,
    文库浓度_LY,最终评价_DJ,最终评价_LY,不合格原因_DJ,不合格原因_LY) %>% 
    rename(run = run_DJ,体系= 体系_DJ, tag = tag_DJ,tag_sample = tag_sample_DJ,目标病原 = 目标病原_DJ)


  #待检-留样对比 -----------------------------------------------------------------
  # df5_all_compare2
  df5_all_compare_origal = df5 
  df5_cc_stat_final_cut = df5_cc_stat_final %>% select(-c(不合格原因,体系))
  df5_all_compare_origal = df5_all_compare_origal %>% left_join(df5_cc_stat_final_cut,by=c("run" = "RUN","sample" = "实验编号","tag_sample"= "文库编号"))
  
  df5_all_compare_origal <- df5_all_compare_origal %>% group_by(sample) %>% mutate(
      `总人内参` = sum(ifelse(str_detect(patho_tag, "人内参"), patho_RPK, 0)),
      `外源内参` = sum(ifelse(str_detect(patho_tag, "外源内参"), patho_RPK, 0))) %>% select(
        run,体系,date,sample,tag,tag_sample,型别,原始数据,Q30,外源内参,总人内参,
        patho_namezn,文库浓度,drug_info,filter_flag,patho_RPK,质控评价,最终评价)
  
  sample_compare_df2 = sample_compare_df %>% pivot_longer(cols = c(sample_DJ, sample_LY),names_to = "con",values_to = "sample") %>%
    mutate(con = gsub("sample_", "", con)) %>% select(-c(con_DJ,con_LY))
  
  df5_all_compare = df5_all_compare_origal %>% left_join(sample_compare_df2,by = c("sample" = "sample"))
  df5_all_compare = df5_all_compare %>% mutate(across(c(patho_RPK,原始数据,Q30),~as.numeric(.)))
  

  
  #解决由filter_flag导致的：! Can't convert `fill` <double> to <list>.的问题
  df5_all_compare =df5_all_compare %>%  filter(!is.na(Group))
  df5_all_compare_temp <- df5_all_compare %>% group_by(Group, patho_namezn, con) %>% summarise(patho_RPK = sum(patho_RPK),.groups = "drop") %>% distinct() %>%
    pivot_wider(id_cols = c(Group, patho_namezn), names_from = con, values_from = patho_RPK, values_fill = 0) %>%
    rename(patho_rpk_DJ = DJ, patho_rpk_LY = LY) %>%ungroup()
  
  
  df5_all_compare_temp = df5_all_compare_temp %>% left_join(sample_compare_df,by=c("Group" = "Group")) %>% select(-c(con_DJ,con_LY)) %>%
    left_join(df5_all_compare %>% select(-c(patho_RPK,patho_namezn)),by=c("sample_DJ" = "sample"),relationship = "many-to-many") %>% 
    left_join(df5_all_compare %>% select(-c(patho_RPK,patho_namezn)),by=c("sample_LY"="sample"), suffix=c("_DJ","_LY"),relationship = "many-to-many") %>% 
    rename(体系=体系_DJ,date = date_DJ,tag = tag_DJ,run = run_DJ) %>% 
    select(run,体系,date,tag,sample_DJ,sample_LY,tag_sample_DJ,tag_sample_LY,型别_DJ,型别_LY,原始数据_DJ,原始数据_LY,
           Q30_DJ,Q30_LY,总人内参_DJ,总人内参_LY,外源内参_DJ,外源内参_LY,patho_namezn,patho_rpk_DJ,patho_rpk_LY,
           质控评价_DJ,质控评价_LY,文库浓度_DJ,文库浓度_LY,最终评价_DJ,最终评价_LY,drug_info_DJ,drug_info_LY)%>% distinct() 
  
  
  ##添加filter_flag
  df5_all_compare_filter_info = df5_all_compare %>% select(sample,patho_namezn,filter_flag) %>% distinct()
  df5_all_compare_temp = df5_all_compare_temp %>% 
    left_join(df5_all_compare_filter_info,by=c("sample_DJ" = "sample","patho_namezn" = "patho_namezn"),relationship = "many-to-many") %>% 
    left_join(df5_all_compare_filter_info,by=c("sample_LY"="sample","patho_namezn" = "patho_namezn"), suffix=c("_DJ","_LY"),relationship = "many-to-many") %>% 
    distinct()
  
  
  ###添加同一种病原计数信息
  df5_all_compare = df5_all_compare_temp
  df5_all_compare=  df5_all_compare %>% group_by(patho_namezn) %>% mutate(count = n())
  
  
  ##双向补充，tag_sample 信息
  df5_all_compare <- df5_all_compare %>%
    mutate(tag_sample_DJ = coalesce(tag_sample_DJ, tag_sample_LY),
           tag_sample_LY = coalesce(tag_sample_LY, tag_sample_DJ))
  
  
  ##添加生产批号：
  df5_all_batch = df3 %>% select(文库编号,生产批号) %>% distinct() %>% rename("sample" = "文库编号")
  df5_all_compare = df5_all_compare %>% left_join(df5_all_batch,by=c("sample_LY" = "sample")) %>% rename("生产批号_LY" = "生产批号")
  df5_all_compare = df5_all_compare %>% left_join(df5_all_batch,by=c("sample_DJ" = "sample")) %>% rename("生产批号_DJ" = "生产批号")
  
  ##过滤
  df5_all_compare = df5_all_compare %>% filter(
    (str_detect(drug_info_DJ,"肺炎") & str_detect(drug_info_LY,"肺炎")) | (str_detect(drug_info_DJ,"百日咳") & str_detect(drug_info_LY,"百日咳")) | is.na(drug_info_DJ) | is.na(drug_info_LY))
  
  df5_all_compare$patho_rpk_DJ[is.na(df5_all_compare$patho_rpk_DJ)] <- 0
  df5_all_compare$patho_rpk_LY[is.na(df5_all_compare$patho_rpk_LY)] <- 0
  
  
  #修改df5_all_compare的表头
  df5_all_compare = df5_all_compare %>% 
    select(run,体系,tag,tag_sample_DJ,patho_namezn,sample_DJ,sample_LY,patho_rpk_DJ,patho_rpk_LY,
           原始数据_DJ,原始数据_LY,Q30_DJ,Q30_LY,外源内参_DJ,外源内参_LY,总人内参_DJ,
           总人内参_LY,质控评价_DJ,质控评价_LY,生产批号_LY,生产批号_DJ,filter_flag_DJ,filter_flag_LY,
           文库浓度_DJ,文库浓度_LY,最终评价_DJ,最终评价_LY,drug_info_DJ,drug_info_LY) %>% 
    rename("检出病原" = "patho_namezn","tag_sample" = "tag_sample_DJ",
           "检出病原RPK_DJ" = "patho_rpk_DJ","检出病原RPK_LY" = "patho_rpk_LY")
  
  
  
  ##20240722修订：耐药情况添加至添加到 检出病原 中（留样-待检对比）
  df5_all_compare_t1 = df5_all_compare %>% ungroup() %>% select(-drug_info_DJ,-drug_info_LY) %>% distinct()

  ##20240914：修复bug, DJ和LY都无耐药信息或 DJ无耐药信息时，最终造成检出病原为空的情况
  df5_all_compare_t2 = df5_all_compare %>% ungroup() %>% select(-c("检出病原",matches("检出病原RPK"))) %>% 
    filter(!(is.na(drug_info_DJ) & is.na(drug_info_LY))) %>% 
    separate(drug_info_DJ,sep = "\\|",c("检出病原_DJ","filter_flag_DJ","检出病原RPK_DJ"),remove = TRUE) %>% 
    separate(drug_info_LY,sep = "\\|",c("检出病原_LY","filter_flag_LY","检出病原RPK_LY"),remove = TRUE) %>% 
    mutate(检出病原_DJ = case_when(is.na(检出病原_DJ) ~ 检出病原_LY,TRUE ~ 检出病原_DJ)) %>%    #以DJ的耐药信息代表检出病原（耐药）
    rename("检出病原" = "检出病原_DJ") %>% select(-c(检出病原_LY)) %>% distinct()
  
  df5_all_compare_t1 = df5_all_compare_t1 %>% mutate_at(vars(matches("检出病原RPK")),as.numeric)
  df5_all_compare_t2 = df5_all_compare_t2 %>% mutate_at(vars(matches("检出病原RPK")),as.numeric)
  df5_all_compare = bind_rows(df5_all_compare_t1,df5_all_compare_t2) %>% distinct()
  
  df5_all_compare = df5_all_compare %>% mutate(across(matches("检出病原RPK"),~replace_na(.,0)))
  } else {
    print("没有对比信息")
    }




# 写入保存 --------------------------------------------------------------------

#格式调整
df5_cc_other_patho_final = df5_cc_other_patho %>% 
  rename(
  "总样本数" = "same_batch_num",
  "病原名" = "patho_namezn",
  "检出样本数" = "total_sample",
  "病原RPK中位数" = "RPK_median",
  "样本频率" = "sample_frequency"
  ) %>% as_tibble()


#调整列名顺序：把DJ放前，LY放后：
if (nrow(sample_compare_df) > 0) {
  df5_all_compare2 =df5_all_compare
  df6_stat2 = df6_stat

  colnames(df5_all_compare2) <- gsub("^_", "", gsub("(.*)(_DJ)", "\\2_\\1", colnames(df5_all_compare2)))
  colnames(df5_all_compare2) <- gsub("^_", "", gsub("(.*)(_LY)", "\\2_\\1", colnames(df5_all_compare2)))
  colnames(df6_stat2) <- gsub("^_", "", gsub("(.*)(_DJ)", "\\2_\\1", colnames(df6_stat2)))
  colnames(df6_stat2) <- gsub("^_", "", gsub("(.*)(_LY)", "\\2_\\1", colnames(df6_stat2)))
  } else {
    print ("没有对比信息")
    }

df5_cc_stat = df5_cc_stat %>% as.data.frame()
df5_cc_stat = df5_cc_stat %>% mutate(其它病原 = ifelse(其它病原 == "NA|NA|NA", "", 其它病原))
df5_cc_stat = df5_cc_stat %>% mutate(其它病原 = ifelse(is.na(其它病原), "", 其它病原))
df5_cc_stat = df5_cc_stat %>% mutate(其它病原 = ifelse(其它病原 == "NA", "", 其它病原))
df5_cc_stat = df5_cc_stat %>% mutate(resis_info = ifelse(resis_info == "NULL", "", resis_info)) 


                                   
#保存
data_frames <- list("汇总" = df5_cc_stat)
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







# 绘图 ----------------------------------------------------------------------

#按体系区分
draw_scattler_plot = function(data_name,aes_x,aes_y,col_value,shape_value){
  ggplot(data_name,aes(x = !!sym(aes_x),y = !!sym(aes_y),color = !!sym(col_value),shape = !!sym(shape_value))) +
    geom_point(size = 1.5,alpha = 0.4) + 
    geom_abline(intercept = 0, slope = 1, color = "#FF6600", linetype = "dashed",linewidth = 1) +
    geom_abline(intercept = 0, slope = 0.5, color = "green",linetype = "dashed",linewidth = 0.3) +
    geom_abline(intercept = 0, slope = 0.25, color = "red",linetype = "dashed",linewidth = 0.3) +   
    geom_abline(intercept = 0, slope = 2, color = "green",linetype = "dashed",linewidth = 0.3) + 
    geom_abline(intercept = 0, slope = 4, color = "red",linetype = "dashed",linewidth = 0.3) +
    scale_x_continuous(limits = c(0,max(data_name[[aes_x]], data_name[[aes_y]]))) +
    scale_y_continuous(limits = c(0,max(data_name[[aes_x]], data_name[[aes_y]])))+
    coord_fixed() + theme_bw() + 
    theme(text = element_text(size = 8), 
          axis.text = element_text(size = 6), 
          axis.title = element_text(size = 6),
          plot.title = element_text(size = 8), 
          legend.text = element_text(size = 6), 
          legend.title = element_text(size = 6))
  }


draw_ratio_plot = function(data_name,aes_x,aes_y,col_value,shape_value){
  ggplot(data_name, aes(!!sym(aes_x), !!sym(aes_y), color = !!sym(col_value),shape = !!sym(shape_value))) + 
    geom_point(size = 1.5, alpha = 0.6) + 
    scale_color_manual(values = c("不合格" = "red", "合格" = "blue"))+
    geom_hline(yintercept = 1.0, color = "black", linewidth = 0.3) +
    geom_hline(yintercept = 0.7, color = "grey", linetype = "dashed", linewidth = 0.3) +
    geom_hline(yintercept = 0.5, color = "grey", linetype = "dashed", linewidth = 0.3) +
    theme_bw() +           
    theme(panel.grid = element_blank(),
          text = element_text(size = 8), 
          axis.text = element_text(size = 6), 
          axis.title = element_text(size = 6),
          plot.title = element_text(size = 8), 
          legend.text = element_text(size = 6), 
          legend.title = element_text(size = 6) 
    )
}



all_plots <- list()
tixi = df5_cc_stat$体系 %>% unique()
tixi_n = length(tixi)
## 质控散点图 -------------------------------------------------------------------
if(nrow(sample_compare_df) > 0){
  sample_compare_df = sample_compare_df %>% filter(!is.na(sample_DJ) & !is.na(sample_LY))
}

if (nrow(sample_compare_df) > 0){
  for (i in 1:tixi_n) {
    
    tixi_item = tixi[i]
    df6_stat_tixi = df6_stat %>% filter(体系 == tixi_item)
    compare_list = c("原始数据","Q30","总人内参","外源内参")
    compare_n = length(compare_list)
    
    for (k in 1:compare_n) {
      compare_item = compare_list[k]
      # 清理Inf、-Inf 或 NaN 的行
      df6_stat_clean <- df6_stat_tixi[is.finite(df6_stat_tixi[[paste0(compare_item, "_DJ")]]) & is.finite(df6_stat_tixi[[paste0(compare_item, "_LY")]]),]
      
      if (nrow(df6_stat_clean) > 0) {
        duibi_p = draw_scattler_plot(
          data_name = df6_stat_clean,
          aes_x = paste0(compare_item, "_DJ"),
          aes_y = paste0(compare_item, "_LY"),
          col_value = "tag_sample",
          shape_value = "生产批号_DJ") + 
          ggtitle(paste0(tixi_item,"-",compare_item, "-所有样本", "-对比"))
        # 将图形对象添加到列表中
        all_plots[[paste0(tixi_item,"-duibi_qc-", compare_item)]] <- duibi_p
      }
    }
  }
} else {
  print("没有DJ和LY的对比信息，无法绘制质控散点图")
  }





## 总病原散点图 ------------------------------------------------------------------
if (nrow(sample_compare_df) > 0){
  
  compare_all_patho = df5_all_compare
  
  for (i in 1:tixi_n) {
    tixi_item = tixi[i]
    compare_all_patho_tixi = compare_all_patho %>% filter(体系 == tixi_item)
    
    compare_all_patho_tixi <- compare_all_patho_tixi[
      is.finite(compare_all_patho_tixi[["检出病原RPK_DJ"]]) & 
        is.finite(compare_all_patho_tixi[["检出病原RPK_LY"]]),]

    if (nrow(compare_all_patho_tixi) > 0) {
      # 绘制图形
      patho_all_p = draw_scattler_plot(
        data_name = compare_all_patho_tixi,
        aes_x = "检出病原RPK_DJ",
        aes_y = "检出病原RPK_LY",
        col_value = "tag_sample",
        shape_value = "生产批号_DJ") +
        ggtitle(paste0(tixi_item,"-所有病原", "-对比")) 
      # 将图形对象添加到列表中
      all_plots[[paste0(tixi_item,"-patho_p-","所有病原")]] <- patho_all_p
    }
  }
}else{
  print ("没有DJ和LY的对比信息，无法绘制总病原散点图")
}




## 目标病原总体散点图 -----------------------------------------------------------------
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
        duibi_p = draw_scattler_plot(
          data_name = df6_stat_clean,
          aes_x = paste0(compare_item, "_DJ"),
          aes_y = paste0(compare_item, "_LY"),
          col_value = "tag_sample",
          shape_value = "生产批号_DJ") + 
          ggtitle(paste0(tixi_item,"-",compare_item, "-所有样本", "-对比"))
        # 将图形对象添加到列表中
        all_plots[[paste0(tixi_item,"-duibi_qc-", compare_item)]] <- duibi_p
      }
    }
  }
} else{
  print("没有DJ和LY的对比信息，无法绘制质控散点图")
}




## 所有病原的单个对比图 --------------------------------------------------------------
#ratio图和散点图

if (nrow(sample_compare_df) > 0){
  for (i in 1:tixi_n) {
    tixi_item = tixi[i]
    compare_specif_df = df5_all_compare %>% filter(体系 == tixi_item)
    
    compare_specif_list = compare_specif_df$检出病原[!is.na(compare_specif_df$检出病原) & compare_specif_df$检出病原 != "" & compare_specif_df$检出病原 !="/"] %>% unique()
    compare_specif_list = stri_sort(compare_specif_list, locale = "zh_CN")
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
        compare_specif_p2 = draw_ratio_plot(
          data_name = compare_specif_df_plot,
          aes_x = "RPK_sum",
          aes_y = "RPK_ratio",
          col_value = "plot_tag",
          shape_value = "生产批号_DJ") + 
          labs(y = "Patho_DJ/Patho_LY") +
          ggtitle(paste0(tixi_item,"-",compare_specif_item, "(n=",count$n,")"))
        # 将图形对象添加到列表中
        all_plots[[paste0("1-patho_com",tixi_item,"_", compare_specif_item)]] <- compare_specif_p2
        
        
        # 绘制散点图
        compare_specif_p  = draw_scattler_plot(
          data_name = compare_specif_df_plot,
          aes_x = "检出病原RPK_DJ",
          aes_y = "检出病原RPK_LY",
          col_value = "tag_sample",
          shape_value = "生产批号_DJ") + 
          ggtitle(paste0(tixi_item,"-",compare_specif_item, "-对比"))
        # 将图形对象添加到列表中
        all_plots[[paste0("2-patho_com",tixi_item,"_", compare_specif_item)]] <- compare_specif_p
        
      }
    }
  } 
}else {
  print("没有DJ和LY的对比信息，无法绘制单个病原对比分析图")
}

## 图形导出为PDF ----------------------------------------------------------------
multi_page_plots <- marrangeGrob(all_plots, nrow = 2, ncol = 2,as.table=FALSE)
pdf(args$comparepdf, onefile = TRUE, width = 8, height = 8, family = "GB1")
print(multi_page_plots)
dev.off()



# 回顾性分析 -------------------------------------------------------------------
#说明：回顾性分析用的较少，需求不是很明确，因此很久没有维护。
## 筛选本轮数据 --------------------------------------------------------

##20240716：注意可能出现单次质检没有企参、NTC、NEG的情况
df7 = df5 %>% select(-drug_info,-resis_MutLog,-patho_tag) %>% filter(体系 %in% c("T2P2","T2P3","T11A","T11B","T3P2","T3P3") & !(tag_sample %in% c("临床样本","其它")))


## 个性化调整 -------------------------------------------------------------------
##修改名称以让patho_namezn和型别一致
df7 <- df7 %>% mutate(patho_namezn= case_when(grepl("人腮腺炎病毒2型（人副流感病毒2型）", patho_namezn) ~ "人副流感2型", TRUE ~ patho_namezn )) 
df7 <- df7 %>% mutate(patho_namezn= case_when(grepl("外源", patho_namezn) ~ "三叶草",TRUE ~ patho_namezn )) 
df7 <- df7 %>% mutate(tag= case_when(grepl("R1", tag) ~ "R01",grepl("R2", tag) ~ "R02",TRUE ~ tag))  
df7 <- df7 %>% mutate(型别= case_when(grepl("阳性对照品",tag_sample) & grepl("枯草芽孢杆菌", 型别) ~ "阳性对照品",TRUE ~ 型别))
df7_consist <- df7 %>% filter(str_detect(patho_namezn, fixed(型别)) | str_detect(patho_namezn, "三叶草") | str_detect(patho_namezn, "内参")) 


## 添加至回顾性表中 ----------------------------------------------------------------
df7_old = read.xlsx(args$input6,sheet = "Sheet 1")
df7_old2 = read.xlsx(args$input6,sheet = "临床反馈")

df7_old = df7_old %>%  select(
  run,date,体系,sample,tag,tag_sample,型别,proty,proid,prmty,生产批号,产品检类别,
  成品对应中间品批号,生产工艺,核酸提取日期,核酸重复次数,提取重复次数,文库浓度,Pooling体积,
  patho_namezn2,patho_namezn,filter_flag,patho_RPK,patho_reads,质控评价,QC_flag,临床反馈,
  原始数据,Q30,过滤后数据量,质控合格比例,有效数据量,有效数据比例,提取试剂规格,提取试剂批号,
  企参编号,resis_name,总人内参RPK)
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


##20240716：检查本轮次质检是否包含企参、NTC、NEG样本，若不包含，则直接终止执行，并生成pre-succeed.log文件
if (nrow(df7_consist)==0) {
  unlink(output_dir, recursive = TRUE)
  file.create(paste0(args$input_run,"/02.Macro/05.QA/pre-succeed.log"))
  stop("本轮次质检不包含企参、NTC、NEG样本")
}



## 绘制回顾性图 ------------------------------------------------------------------
# 创建一个空的列表来存储所有的图形对象
all_retro_plot <- list()
tixi = df7_consist$体系 %>% unique() #只绘制本轮实验的体系
tixi_n = length(tixi)


#绘制内参RPK分布图，包括内参和外源内参
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
  

### 绘制外源内参RPK分布图 ------------------------------------------------------------
#1：所有的企参；2：NEG（阴性对照品）一张
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

  
  
  

### 绘制总人内参 ------------------------------------------------------------------
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




### 绘制目标病原RPK分布图 ------------------------------------------------------------
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




# 结束 ----------------------------------------------------------------------
# 删除目录
unlink(output_dir, recursive = TRUE)
# 创建一个空的succeed.log文件
file.create(paste0(args$input_run,"/02.Macro/05.QA/pre-succeed.log"))

