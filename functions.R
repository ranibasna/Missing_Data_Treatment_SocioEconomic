# load data
# data_all <- read_dta("/home/rstudio/socioeconomics/OriginalData/Analysis_dataset(60)25.2.21.dta.dta")

# first gitclone the current repo
# In order to reproduce the analysis workflow first use the generated singularity image on an hpc environment and the run the 
# following R file using for instance this job file. After finishing the job save the outputs in the intermediate/outputs and 
# use the saved objects to run the target workflow by running tar_make(). check meybe we need to run first renv::init() or restor

## For me do not put thoses resulted saved objects publicly.

# imputation functions ----

Prepare_data <- function(Smok_Soci_data){
  # make it a data frame object
  my_f_data <- as.data.frame(Smok_Soci_data)
  # dropping uneccesary variables
  drops <- c("ID","cohort")
  my_f_data <- my_f_data[ , !(names(my_f_data) %in% drops)]
  # dropping categorized variables 
  my_f_data <- my_f_data %>% select(-c(cbmi, agecateg, cduration))
  # drop variables with high correlations
  drops_corr <- c("weight", "quitage")
  my_f_data <- my_f_data[ , !(names(my_f_data) %in% drops_corr)]
  # removing non-related variables
  drops_rel <- c("birthyear","height","age_group")
  my_f_data <- my_f_data[ , !(names(my_f_data) %in% drops_rel)]
  # drop more correlated vars
  #drops_corr_cat_2 <- c("asthma_treatmnt","varq10b","cbc","varq10c")
  drops_corr_cat_2 <- c("asthma_treatmnt","cbc")
  my_f_data <- my_f_data[ , !(names(my_f_data) %in% drops_corr_cat_2)]
  
  # if mice is running then also s_amount
  my_f_data <- my_f_data %>% select(-c(asthma_diagnosed, asthma, s_amount))
  
  # from mice models out variables
  my_f_data <- my_f_data %>% select(-c(e_smoking))
  
  # corr_3 correlated with the outcome c_asthma
  drops_corr_cat_3 <- c("alle_asthma","noalle_asthma","w_asthma")
  my_f_data <- my_f_data[ , !(names(my_f_data) %in% drops_corr_cat_3)]
  # remove any_smp and only_symptoms
  my_f_data <- my_f_data %>% select(-c(any_smp, only_symptoms)) # did help a lot
  # trt_copd
  my_f_data <- my_f_data %>% select(- trt_copd) # did help
  # edu_credits
  my_f_data <- my_f_data %>% select(- edu_credits) # did help
  
  # converting variables to factor and numerical
  num_cols <- colnames(my_f_data %>% select( c(BMI, age,duration,startage)))
  fact_cols <-  setdiff(colnames(my_f_data), num_cols)
  # mutare to factors and num
  my_f_data <- my_f_data %>% mutate_at(num_cols, as.numeric)
  my_f_data <- my_f_data %>% mutate_at(fact_cols, factor)
  
  return(my_f_data)
}

# to conclude  we need to remove the edu_credit, s_amount, her_dis, herditery_puldis, any_symp, only_symp, trt_copd
# we need to recreate the any_smp and only_symp afterwords

# data preprocssing

Preprocess_Data <- function(Ready_Raw_data){
  # check the data typee
  if (!(is.data.frame(Ready_Raw_data))){
    stop("The input  is not a dataframe format")
  }
  # ordinal as orderd variables 
  Ready_Raw_data$jabstatus <- ordered(Ready_Raw_data$jabstatus, levels=1:8)
  Ready_Raw_data$sei_class <- ordered(Ready_Raw_data$sei_class, levels=0:7)
  Ready_Raw_data$smoking_status <- ordered(Ready_Raw_data$smoking_status, levels=0:2)
  
  #data_all$education <- ordered(data_all$education, levels=0:2)
  #Ready_Raw_data$edu_credits <- ordered(Ready_Raw_data$edu_credits, levels=0:6)
  #Ready_Raw_data$s_amount <- ordered(Ready_Raw_data$s_amount,levels=0:3)
  Ready_Raw_data$e_amount <- ordered(Ready_Raw_data$e_amount,levels=1:3)
  
  # more ordinal
  Ready_Raw_data$syk_class <- ordered(Ready_Raw_data$syk_class,levels=0:10)
  Ready_Raw_data$SSY_class <- ordered(Ready_Raw_data$SSY_class,levels=0:10) #(2012 classification)
  
  # remove the 2012 classification
  Ready_Raw_data <- Ready_Raw_data %>% select(- SSY_class)
  
  return(Ready_Raw_data)
}


# this function will run a minimal case for a computation reasons for a full case we used the HCP cluster
impute_missing_data_mice <- function(processed_missing_data, miss_seed){
  # check the seed
  if(missing(miss_seed)){
    set.seed(11)
  }else{
    set.seed(miss_seed)
  }
  # prepare the pred matrix
  pred <- make.predictorMatrix(processed_missing_data)
  # due to high depndencies between some variables we imopse which variables to include in each of the imputation models.
  pred[c("hereditery_asthma","herditery_pulldis"),c("herditery_pulldis","hereditery_asthma")] <- 0
  pred[c("hereditery_allergy","herditery_pulldis"),c("herditery_pulldis","hereditery_allergy")] <- 0
  pred[c("hereditery_allergy","hereditery_asthma"),c("hereditery_asthma","hereditery_allergy")] <- 0
  pred[c("hereditery_asthma"),c("c_asthma")] <- 0
  pred[c("her_dis"),c("smoking_status")] <- 0
  # remove education from predicting missing values in edu_credits
  # pred[c("education"),c("edu_credits")] <- 0
  #pred[c("edu_credits"),c("education")] <- 0
  #
  # n.core is number of cores and n.imp.cores number of imputations per core
  #imp_parl_final <- parlmice(data = processed_missing_data, n.core = 8, n.imp.core = 7, maxit = 40, predictorMatrix = pred, seed = 11)
  Imputed_data <- mice(data = processed_missing_data, m = 2, maxit = 2, predictorMatrix = pred, seed = miss_seed)
  
  return(Imputed_data)
}



# # test
# my_data <- Prepare_data(Smok_Soci_data = data_all)
# my_data <- Preprocess_Data(Ready_Raw_data = my_data)
# my_data <- my_data %>% select(- c(varq6a, varq6b, varq11, varq12)) # it still no convergence
# my_data <- my_data %>% select(- hereditery_allergy)
# my_data <- my_data %>% select(- cbc)
# my_data <- my_data %>% select(- dplyr::matches('varq'))
# 
# # we need varq 7,8,9,10
# imputed_data <- impute_missing_data_mice(processed_missing_data = my_data, miss_seed = 22)
# imputed_data <- impute_missing_data_mice(processed_missing_data = my_data, miss_seed = 11)
# 
# 
# # test missforest package
# library(missForest)
# imp_my_data <- missForest(my_data, verbose = TRUE)

# # saving the mice object
# save(imp_parl_final,file = "~/Soci_smok_proj/Results/final_mice_model.RData")
# 
# 

# Bayesian Network functions ----

Prepare_data_bn <- function(raw_correlated_data, imputed_data){
  # some preprocessing
  data_all <- raw_correlated_data %>% select(w_asthma, noalle_asthma, alle_asthma)
  data_all <- data_all %>% mutate_all(factor)
  # feature engineer the variables cbc, any_smp, and only_symptoms
  #imputed_data <- imputed_data %>% dplyr::mutate(cbc = case_when(varq8a ==1 & varq8b==1 & varq8c==1 ~ 1))
  imputed_data <- imputed_data %>% dplyr::mutate(cbc = dplyr::if_else(varq8a ==1 & varq8b==1 & varq8c==1,1,0)) %>%
  dplyr::mutate( any_smp = dplyr::if_else(varq7 == 1 | varq8a ==1 | varq8b ==1 | varq8c==1 | varq9 ==1 | varq10a==1 |varq10b==1, 1,0)) %>% 
  dplyr::mutate(only_symptoms = dplyr::if_else(c_asthma ==1 & any_smp == 1, 1,0))  
  imputed_data <- imputed_data %>% dplyr::mutate_at(vars(any_smp, only_symptoms, cbc), factor)   
  # bind the two data set
  data_modeling <- cbind(imputed_data, data_all)
  # remove some variables symptoms
  data_modeling <- data_modeling %>% select(- dplyr::matches('varq'))
  return(data_modeling)
}

plot.network <- function(structure, ht = "400px"){
  nodes.uniq <- unique(c(structure$arcs[,1], structure$arcs[,2]))
  nodes <- data.frame(id = nodes.uniq,
                      label = nodes.uniq,
                      color = "darkturquoise",
                      shadow = TRUE)
  edges <- data.frame(from = structure$arcs[,1],
                      to = structure$arcs[,2],
                      arrows = "to",
                      smooth = TRUE,
                      shadow = TRUE,
                      color = "black")
  return(visNetwork(nodes, edges, height = ht, width = "100%"))
}

drop_vars_df <- function(data_drop, drop_var){
  assertthat::assert_that(is.vector(drop_var))
  data_drop <- data_drop[ , !(names(data_drop) %in% drop_var)]
  return(data_drop)
}

# conditional probability function ----
cpq_effe_modif <- function(.data, vars, outcome, state, model, repeats = 500000) {
  all.levels <- if (any(length(vars) > 1)) {
    lapply(.data[, (names(.data) %in% vars)], levels)
  } else {
    all.levels <- .data %>%
      select(all_of(vars)) %>%
      sapply(levels) %>%
      as_tibble()
  }
  combos <- do.call("expand.grid", c(all.levels, list(stringsAsFactors = FALSE))) # al combiations
  
  # generate character strings for all combinations
  str1 <- ""
  for (i in seq(nrow(combos))) {
    str1[i] <- paste(combos %>% names(), " = '",
                     combos[i, ] %>% sapply(as.character), "'",
                     sep = "", collapse = ", "
    )
  }
  
  # repeat the string for more than one outcome
  str1 <- rep(str1, times = length(outcome))
  str1 <- paste("list(", str1, ")", sep = "")
  
  # repeat loop for outcome variables (can have more than one outcome)
  all.levels.outcome <- if (any(length(outcome) > 1)) {
    lapply(.data[, (names(.data) %in% outcome)], levels)
  } else {
    all.levels <- .data %>%
      select(all_of(outcome)) %>%
      sapply(levels) %>%
      as_tibble()
  }
  combos.outcome <- do.call("expand.grid", c(all.levels.outcome))
  
  # repeat each outcome for the length of combos
  str3 <- rep(paste("(", outcome, " == '", state, "')", sep = ""), each = length(str1) / length(outcome))
  
  # fit the model
  #fitted <- bn.fit(cextend(model), .data, method = "bayes", iss = 1)
  fitted <- bn.fit(cextend(model), .data)
  
  # join all elements of string together
  #cmd <- paste("cpquery(fitted, ", str3, ", ", str1, ", method = 'lw', n = ", repeats, ")", sep = "")
  cmd <- paste("replicate(200,cpquery(fitted, ", str3, ", ", str1, ", method = 'lw', n = ", repeats, "))", sep = "")
  
  prob <- rep(0, length(str1)) # empty vector for probabilities
  q05 <- rep(0,length(str1))
  q975 <- rep(0,length(str1))
  #print(eval(parse(text =  cmd[1])))
  for (i in seq(length(cmd))) {
    prop_vec = eval(parse(text =  cmd[i]))
    #print(quantile(prop_vec, 0.05))
    q05[i] = quantile(prop_vec, 0.05)
    q975[i] = quantile(prop_vec,0.975)
    prob[i] <- mean(prop_vec)
  } # for each combination of strings, what is the probability of outcome
  res <- cbind(combos, prob, q05, q975)
  
  return(res)
}
#
get_cpq_plot_one_var <- function(res_data, effe_modif_vars, original_raw_data, final_data){
  # get the var cases
  var1Cases <- unique(final_data[,effe_modif_vars[1]])
  #var2Cases <- unique(final_data[,effe_modif_vars[2]])
  # get the var labels
  Var1Labels <- names(attributes(unique(original_raw_data[,effe_modif_vars[1]]))$labels)
  #
  var_1_sym <- sym(effe_modif_vars[1])
  # define conditions
  conditions_1 <- purrr::map2(var1Cases, Var1Labels, ~quo( !!var_1_sym == !!.x ~ !!.y))
  
  # mutate the new coloumns
  res_data <- res_data %>% mutate("{effe_modif_vars[1]}_Cases" := case_when(!!!conditions_1)) 
  res_colnames <- colnames(res_data)
  var1 <- sym(res_colnames[grepl("_Cases",res_colnames)])
  #prop_p <- ggplot(res_data, aes(x = !!var1, y = prob))  + geom_errorbar( aes(ymin = q05, ymax = q975, color = !!var1), position = position_dodge(0.3), width = 0.2) + geom_point(aes(color = !!var1), position = position_dodge(0.3)) + scale_color_brewer() + theme_classic() + scale_x_discrete(labels = function(x) {stringr::str_wrap(x, width = 16)})
  #prop_p <- ggplot(res_data, aes(x = !!var1, y = prob))  + geom_errorbar( aes(ymin = q05, ymax = q975, color = !!var1), position = position_dodge(0.3), width = 0.2) + geom_point(aes(color = !!var1), position = position_dodge(0.3)) + scale_color_viridis(discrete = TRUE, option = "D") + theme_classic() + scale_x_discrete(labels = function(x) {stringr::str_wrap(x, width = 16)})
  prop_p <- ggplot(res_data, aes(x = !!var1, y = prob))  + geom_errorbar( aes(ymin = q05, ymax = q975, color = !!var1), position = position_dodge(0.3), width = 0.2) + geom_point(aes(color = !!var1), position = position_dodge(0.3)) + theme_classic() + scale_x_discrete(labels = function(x) {stringr::str_wrap(x, width = 16)})
  res_list <- list()
  res_list[[1]] <- res_data
  res_list[[2]] <- prop_p
  return(res_list)
}
#
get_cpq_plot <- function(res_data, effe_modif_vars, original_raw_data, final_data){
  # get the var cases
  var1Cases <- unique(final_data[,effe_modif_vars[1]])
  var2Cases <- unique(final_data[,effe_modif_vars[2]])
  # get the var labels
  Var1Labels <- names(attributes(unique(original_raw_data[,effe_modif_vars[1]]))$labels)
  Var2Labels <- names(attributes(unique(original_raw_data[,effe_modif_vars[2]]))$labels)
  #
  var_1_sym <- sym(effe_modif_vars[1])
  var_2_sym <- sym(effe_modif_vars[2])
  #browser()
  # define conditions
  conditions_1 <- purrr::map2(var1Cases, Var1Labels, ~quo( !!var_1_sym == !!.x ~ !!.y))
  conditions_2 <- purrr::map2(var2Cases, Var2Labels, ~quo( !!var_2_sym == !!.x ~ !!.y))
  # mutate the new coloumns
  res_data <- res_data %>% mutate("{effe_modif_vars[1]}_Cases" := case_when(!!!conditions_1)) %>% mutate("{effe_modif_vars[2]}cases" := case_when(!!!conditions_2))
  # plotting
  # return(res_data)
  #browser()
  res_colnames <- colnames(res_data)
  var1 <- sym(res_colnames[grepl("_Cases",res_colnames)])
  var2 <- sym(res_colnames[grepl("cases",res_colnames)])
  prop_p <- ggplot(res_data, aes(x = !!var1, y = prob))  + geom_errorbar( aes(ymin = q05, ymax = q975, color = !!var2), position = position_dodge(0.3), width = 0.2) + geom_point(aes(color = !!var2), position = position_dodge(0.3)) + scale_color_manual(values = c("#00AFBB", "#E7B800",'#999999')) + theme_classic() + scale_x_discrete(labels = function(x) {stringr::str_wrap(x, width = 16)})
  res_list <- list()
  res_list[[1]] <- res_data
  res_list[[2]] <- prop_p
  return(res_list)
}
# sensitivity analysis functions ----

sens.mice <- function(IM, ListMethod = ListMethod, SupPar = SupPar){
  if(length(ListMethod) > length(names(IM$data))){
    stop("You have specified too much new methods to be applied.")
  } 
  if(length(ListMethod) < length(names(IM$data))){
    stop("You have not specified enough new methods to be applied.")
  }
  cpt <- 0
  for(i in 1:length(ListMethod)){
    if(ListMethod[i]=="MyFunc"){
      if(IM$method[i] == "norm" | IM$method[i] == "pmm" | IM$method[i] == "logreg"){
        cpt <- cpt + 1
      }
      if(IM$method[i] == "polyreg"){
        cpt <- cpt + dim(table(IM$data[i]))-1
      }
    }
    if(ListMethod[i]==""){
      cpt <- cpt
    }
  }
  if(length(SupPar) > cpt){
    stop("You have specified too much supplementary parameters to be applied.")
  } 
  if(length(SupPar) < cpt){
    stop("You have not specified enough supplementary parameters to be applied.")
  } 
  for(i in 1:length(ListMethod)){
    if(ListMethod[i] != "MyFunc" & ListMethod[i] != ""){
      stop("Values available for ListMethod are ''MyFunc'' and '' ''.")
    }
    if(ListMethod[i]=="Myfunc" & (IM$method[i] =="norm.nob")){
      stop("norm.nob is not an available method for the function sens.mice.")
    }
    if(ListMethod[i]=="Myfunc" & (IM$method[i] =="mean")){
      stop("mean is not an available method for the function sens.mice.")
    }
    if(ListMethod[i]=="Myfunc" & (IM$method[i] =="2l.norm")){
      stop("2l.norm is not an available method for the function sens.mice.")
    }    
    if(ListMethod[i]=="Myfunc" & (IM$method[i] =="lda")){
      stop("lda is not an available method for the function sens.mice.")
    }
    if(ListMethod[i]=="Myfunc" & (IM$method[i] =="sample")){
      stop("sample is not an available method for the function sens.mice.")
    }  
  } 
  j <- 0
  cpt <- 0
  IMinit <- IM
  MyMethod <- IM$method
  listvar <- names(IM$data)
  SumPr <- matrix(NA, nrow=length(ListMethod[ListMethod=="MyFunc"]), ncol=3)
  for(ii in 1:length(listvar)){
    if(ListMethod[ii]=="MyFunc"){
      j <- j + 1
      cpt <- cpt + 1  
      if(MyMethod[ii]=="pmm" | MyMethod[ii]=="norm" | MyMethod[ii]=="logreg"){
        SumPrtemp <- c(listvar[ii], MyMethod[ii], SupPar[j])
        cat(SumPrtemp)   
      }
      if(MyMethod[ii]=="logreg"){
        if(SupPar[j] < 0){
          stop("Value for odds ratio can't be negative.") 
        }
      }
      if(MyMethod[ii]=="polyreg"){
        tempSupPar <- c(SupPar[j : (j + dim(table(IM$data[ii]))-2)])
        SumPrtemp <- c(listvar[ii], MyMethod[ii], tempSupPar)
        cat(SumPrtemp)
        for(m in 1:length(tempSupPar)){
          if(tempSupPar[m] < 0){
            stop("Value for odds ratio can't be negative.")  
          }
        }
      } 
      IMtemp <- IM
      IMtemp$pad$method <- c(rep("", length(names(IM$data))), rep("dummy", length(IM$method) - length(names(IM$data))))
      IMtemp$pad$method[ii] <- "MyFunc"  
      laps <- lapply(1:IM$m, function(x)mice::complete(IM, x))
      temp <- sapply(laps, function(x)mice.impute.MyFunc(IM$data[,ii], !is.na(IM$data[,ii]), 
                                                         model.matrix(~., data=x[,-which(names(x) == listvar[ii])]), SupPar, MyMethod, ii, j))
      IMinit$imp[[listvar[ii]]] <- temp
      if(MyMethod[ii]=="polyreg"){
        j <- (j + dim(table(IM$data[ii]))-2)
      }
      cat("\n")
      SumPr[cpt, 1] <- SumPrtemp[1]
      SumPr[cpt, 2] <- SumPrtemp[2]
      SumPr[cpt, 3] <- SumPrtemp[3]
      if(length(SumPrtemp) > 3){
        temp <- SumPrtemp[3]
        for(l in 4 : length(SumPrtemp)){
          temp <- paste(temp, SumPrtemp[l], sep=" ; ")  
        }
        SumPr[cpt, 3] <- temp
      }         
    }
    if(ListMethod[ii]==""){
      IMinit$imp[listvar[ii]] <- IMinit$imp[listvar[ii]]
    }
  }
  dimnames(SumPr)[[2]] <- c("Variable", "Method", "SupPar") 
  cat("Summary :")
  cat("\n")
  cat("\n")
  print(SumPr)
  IMfinal <- IMinit
}



mice.impute.MyFunc <- function(y, ry, x, suppar , Mymethod, i, j){
  if(Mymethod[i]=="pmm"){
    x <- cbind(1, as.matrix(x))
    parm <- .norm.draw(y, ry, x)
    parm$beta[1] <- parm$beta[1] + suppar[j]
    yhatobs <- x[ry, ] %*% parm$coef
    yhatmis <- x[!ry, ] %*% parm$beta
    return(apply(as.array(yhatmis), 1, .pmm.match, yhat = yhatobs,
                 y = y[ry]))
  }
  if(Mymethod[i]=="norm"){
    x <- cbind(1, as.matrix(x))
    parm <- .norm.draw(y, ry, x)
    parm$beta[1] <- parm$beta[1] + suppar[j]
    return(x[!ry, ] %*% parm$beta + rnorm(sum(!ry)) * parm$sigma)
  }
  if(Mymethod[i]=="logreg"){
    aug <- augment(y, ry, x)
    x <- as.matrix(aug$x)
    y <- aug$y
    ry <- aug$ry
    w <- aug$w
    suppressWarnings(fit <- glm.fit(x[ry, ], y[ry], family = binomial(link = logit),
                                    weights = w[ry]))
    fit.sum <- summary.glm(fit)
    beta <- coef(fit)
    beta[1] <- beta[1] + log(suppar[j])
    rv <- t(chol(fit.sum$cov.unscaled))
    beta.star <- beta + rv %*% rnorm(ncol(rv))
    p <- 1/(1 + exp(-(x[!ry, ] %*% beta.star)))
    vec <- (runif(nrow(p)) <= p)
    vec[vec] <- 1
    if (is.factor(y)) {
      vec <- factor(vec, c(0, 1), levels(y))
    }
    return(vec)
  }
  if(Mymethod[i]=="polyreg"){
    x <- as.matrix(x)
    aug <- augment(y, ry, x)
    x <- aug$x
    y <- aug$y
    ry <- aug$ry
    w <- aug$w   
    ## check whether this works instead of the assign
    tmpData <- cbind.data.frame(y, x)
    fit <- nnet::multinom(formula(tmpData), data = tmpData[ry, ], weights = w[ry],
                          maxit = 200, trace = FALSE) 
    temp <- matrix(fit$wts, nrow=nlevels(y), byrow=T)  
    for(k in 2:nlevels(y)){
      temp[k, 2] <- temp[k, 2] + log(suppar[j])
      j <- j + 1
    }       
    temp <- t(temp)
    fit$wts <- c(temp[, ])
    post <- predict(fit, tmpData[!ry, ], type = "probs")
    if (sum(!ry) == 1)
      post <- matrix(post, nrow = 1, ncol = length(post))
    fy <- as.factor(y)
    nc <- length(levels(fy))
    un <- rep(runif(sum(!ry)), each = nc)
    if (is.vector(post))
      post <- matrix(c(1 - post, post), ncol = 2)
    draws <- un > apply(post, 1, cumsum)
    idx <- 1 + apply(draws, 2, sum)
    return(levels(fy)[idx])     
  }
}


sens.est <- function(mids.obj, vars_vals, digits=2){
  if(!all(names(vars_vals) %in% names(mids.obj$data))){
    stop("Some variables not in imputed data set")
  }
  if(any(sapply(vars_vals, is.matrix))){
    nums <- lapply(1:length(vars_vals), function(x)1:length(vars_vals))
    eg.nums <- do.call("expand.grid", nums)
    eg <-  cn <- NULL
    for(i in 1:ncol(eg.nums)){
      if(is.matrix(vars_vals[[i]])){
        eg <- cbind(eg, vars_vals[[i]][eg.nums[,i], , drop=F])
        cn <- c(cn, paste(names(vars_vals)[i], 1:ncol(vars_vals[[i]]), sep=""))
      }
      else{
        eg <- cbind(eg, vars_vals[[i]][eg.nums[,i]])
        cn <- c(cn, names(vars_vals)[i])
      }
    }
    colnames(eg) <- cn
  }
  else{
    eg <- do.call(expand.grid, vars_vals)[,,drop=FALSE]
    if(!is.matrix(eg)){
      eg <- matrix(eg[[1]], ncol=1)[,,drop=F]
    }    
    colnames(eg) <- names(vars_vals)
  }
  out <- list()
  for(i in 1:nrow(eg)){                                             
    ListMethod <- ifelse(names(mids.obj$data) %in% names(vars_vals), "MyFunc", "")
    SupPar <- c(unlist(eg[i, ,drop=F]))
    out[[i]] <- sens.mice(mids.obj, ListMethod, SupPar)
  }
  nms <- NULL
  for(i in 1:ncol(eg)){
    nms <- cbind(nms, paste(colnames(eg)[i], round(eg[,i], digits), sep=": "))
  }
  names(out) <- apply(nms, 1, paste, collapse=", ")
  out
}

sens.pool <- function(obj, sensData, impData, ...){
  nconds <- length(sensData)
  condlist <- list()
  j <- 1
  for(l in 1:nconds){
    condlist[[j]] <- list()
    for(i in 1:sensData[[j]]$m){
      condlist[[j]][[i]] <- complete(sensData[[j]], i)
    }
    j <- j+1
  }
  condlist[[j]] <- list()
  for(i in 1:impData$m){
    condlist[[(j)]][[i]] <- complete(impData, i)
  }
  { if(length(names(sensData)) > 0){
    names(condlist) <- c(names(sensData), "mice")
  }                                                
    else{
      names(condlist) <- c(as.character(1:nconds), "mice")
    }}
  cond.mods <- list()
  for(i in 1:length(condlist)){
    cond.mods[[i]] <- list()
    for(j in 1:length(condlist[[i]])){
      tmp <- obj
      attr(tmp$terms, ".Environment") <- environment()
      cond.mods[[i]][[j]] <- update(tmp, . ~ ., data=condlist[[i]][[j]])
    }
  }
  comb.mods <- invisible(lapply(cond.mods, MIcombine))
  sum.mods <- invisible(lapply(comb.mods, summary))
  names(comb.mods) <- names(sum.mods) <- names(condlist) 
  sub <- as.data.frame(rbind(do.call(rbind, sum.mods)))
  varnames <- gsub("mice.", "", grep("^mice", rownames(sub), value=T) , fixed=T)
  sub$vars <- as.factor(rep(varnames, length(condlist)))
  sub$conds <- factor(c(rep(names(condlist), each = length(varnames))), levels=names(condlist))
  rownames(sub) <- NULL
  class(sub) <- c("sens.pool", "data.frame")
  sub
}         

plot.sens.pool <- function(x, ...){
  p <- xyplot(results ~ conds | vars , 
              data=x, scales=list(x=list(rot=45), y=list(relation="free", rot=90)), pch=16, col="black", 
              lower=x[["(lower"]], upper=x[["upper)"]], 
              xlab = "", ylab = "Coefficients with 95% Confidence Intervals",
              prepanel=function (x, y, subscripts, lower, upper,...){
                list(ylim = range(c(lower[subscripts], upper[subscripts]), finite = TRUE))},
              panel=function(x,y,lower,upper,subscripts,...){
                panel.xyplot(x, y, ...)
                panel.segments(x, lower[subscripts], x, upper[subscripts], ...)  
                panel.abline(h=0, lty=3)
              })
  p
}                                             

sens.test <- function(obj, var, sensData, impData, digits=3, ...){
  nconds <- length(sensData)
  condlist <- list()
  j <- 1
  for(l in 1:nconds){
    condlist[[j]] <- list()
    for(i in 1:sensData[[j]]$m){
      condlist[[j]][[i]] <- complete(sensData[[j]], i)
    }
    j <- j+1
  }
  condlist[[j]] <- list()
  for(i in 1:impData$m){
    condlist[[(j)]][[i]] <- complete(impData, i)
  }
  if(length(names(sensData)) > 0){
    names(condlist) <- c(names(sensData), "mice")
  }                                                
  else{
    names(condlist) <- c(as.character(1:nconds), "mice")
  }
  cond.mods <- list()
  for(i in 1:length(condlist)){
    cond.mods[[i]] <- list()
    for(j in 1:length(condlist[[i]])){
      tmp <- obj
      attr(tmp$terms, ".Environment") <- environment()
      cond.mods[[i]][[j]] <- update(tmp, . ~ ., data=condlist[[i]][[j]])
    }
  }
  restr.mods <- list()
  for(i in 1:length(condlist)){
    restr.mods[[i]] <- list()
    for(j in 1:length(condlist[[i]])){
      tmp <- obj
      attr(tmp$terms, ".Environment") <- environment()
      restr.mods[[i]][[j]] <- update(tmp, paste0(". ~ .-", var), data=condlist[[i]][[j]])
    }
  }
  full.devs <- lapply(cond.mods, function(x)sapply(x, deviance))
  restr.devs <- lapply(restr.mods, function(x)sapply(x, deviance))
  names(full.devs) <- names(restr.devs) <- names(condlist)
  df.diff <- df.residual(restr.mods[[1]][[1]]) - df.residual(cond.mods[[1]][[1]])
  chisqs <- lapply(1:length(full.devs), function(i)restr.devs[[i]] - full.devs[[i]])
  out <- sapply(1:length(full.devs), function(i)mean(1-pchisq(chisqs[[i]], df.diff)))
  fmt <- paste0("%.", digits, "f")
  out <- cbind(sprintf(fmt, sapply(chisqs, mean)), sprintf(fmt, out))
  colnames(out) <- c("Average X2", "p-value")
  rownames(out) <- names(full.devs)
  cat("Test for exclusion of ", var, "(", df.diff, " degrees of freedom)\n")
  print(noquote(out))
}


augment <- function (y, ry, x, maxcat = 50, ...) {
  # augment comes from mice v. 2.25.  It was not exported from
  # the namespace so could not be imported from that package here
  # I copied the function in its entirety in the interest of continued compatability
  icod <- sort(unique(unclass(y)))
  k <- length(icod)
  if (k > maxcat) 
    stop(paste("Maximum number of categories (", maxcat, 
               ") exceeded", sep = ""))
  p <- ncol(x)
  if (p == 0) 
    return(list(y = y, ry = ry, x = x, w = rep(1, length(y))))
  if (sum(!ry) == 1) 
    return(list(y = y, ry = ry, x = x, w = rep(1, length(y))))
  mean <- apply(x, 2, mean)
  sd <- sqrt(apply(x, 2, var))
  minx <- apply(x, 2, min)
  maxx <- apply(x, 2, max)
  nr <- 2 * p * k
  a <- matrix(mean, nrow = nr, ncol = p, byrow = TRUE)
  b <- matrix(rep(c(rep(c(0.5, -0.5), k), rep(0, nr)), length = nr * 
                    p), nrow = nr, ncol = p, byrow = FALSE)
  c <- matrix(sd, nrow = nr, ncol = p, byrow = TRUE)
  d <- a + b * c
  d <- pmax(matrix(minx, nrow = nr, ncol = p, byrow = TRUE), 
            d)
  d <- pmin(matrix(maxx, nrow = nr, ncol = p, byrow = TRUE), 
            d)
  e <- rep(rep(icod, each = 2), p)
  dimnames(d) <- list(paste("AUG", 1:nrow(d), sep = ""), dimnames(x)[[2]])
  xa <- rbind.data.frame(x, d)
  if (is.factor(y)) 
    ya <- as.factor(levels(y)[c(y, e)])
  else ya <- c(y, e)
  rya <- c(ry, rep(TRUE, nr))
  wa <- c(rep(1, length(y)), rep((p + 1)/nr, nr))
  return(list(y = ya, ry = rya, x = xa, w = wa))
}



sens.wald <- function(obj, hyps, sensData, impData, digits=3, ...){
  nconds <- length(sensData)
  condlist <- list()
  j <- 1
  for(l in 1:nconds){
    condlist[[j]] <- list()
    for(i in 1:sensData[[j]]$m){
      condlist[[j]][[i]] <- complete(sensData[[j]], i)
    }
    j <- j+1
  }
  condlist[[j]] <- list()
  for(i in 1:impData$m){
    condlist[[(j)]][[i]] <- complete(impData, i)
  }
  if(length(names(sensData)) > 0){
    names(condlist) <- c(names(sensData), "mice")
  }                                                
  else{
    names(condlist) <- c(as.character(1:nconds), "mice")
  }
  cond.mods <- list()
  for(i in 1:length(condlist)){
    cond.mods[[i]] <- list()
    for(j in 1:length(condlist[[i]])){
      tmp <- obj
      attr(tmp$terms, ".Environment") <- environment()
      cond.mods[[i]][[j]] <- update(tmp, . ~ ., data=condlist[[i]][[j]])
    }
  }
  comb.mods <- lapply(cond.mods, MIcombine)
  res <- list()
  for(i in 1:length(comb.mods)){
    res[[i]] <- linearHypothesis.default(comb.mods[[1]], hyps, coef.=coef(comb.mods[[i]], vcov. = vcov(comb.mods[[i]])))
    
  }
  out <- sapply(res, function(x)x[2,])
  fmt <- paste0("%.", digits, "f")
  out2 <- t(array(sprintf(fmt, out), dim=dim(out)))
  colnames(out2) <- rownames(out)  
  rownames(out2) <- names(condlist)
  noquote(out2)
}

# aggregate multiple imputations ----
agglomerate.data<-function(data,imp,Mimp,Method="mice"){
  
  Moy<-Mimp+1
  redata<-as.matrix(data)
  ximp<-array(redata,dim=c(nrow(redata),ncol(redata),Moy))
  ####
  
  if(any(is.na(redata))==TRUE){
    if(Method=="mice" || Method=="amelia" || Method=="missmda" || Method=="hmisc" || Method=="norm"){
      #####################MICE
      if(Method=="mice"){
        
        for(i in 1:Mimp){
          ximp[,,i]<-as.matrix(complete(imp,i))
          
        }
        ##Averaged dataset
        ximp[,,Moy]<-apply(ximp[,,1:Mimp],c(1,2),mean)
      }
      #
      #####################Amelia
      if(Method=="amelia"){
        for(i in 1:Mimp){
          ximp[,,i]<-as.matrix(imp$imputations[[i]])
          
        }
        ##Averaged dataset
        ximp[,,Moy]<-apply(ximp[,,1:Mimp],c(1,2),mean)
      }
      #
      ##
      #####################NORM
      if(Method=="norm"){
        for(i in 1:Mimp){
          ximp[,,i]<-as.matrix(imp[[i]])
          
        }
        ##Averaged dataset
        ximp[,,Moy]<-apply(ximp[,,1:Mimp],c(1,2),mean)
      }
      #
      #####################MDA
      if(Method=="missmda"){
        
        for(i in 1:Mimp){
          ximp[,,i]<-as.matrix(imp$res.MI[,,i])
          
        }
        ##Averaged dataset
        ximp[,,Moy]<-apply(ximp[,,1:Mimp],c(1,2),mean)
      }
      #
      ####################Hmisc
      if(Method=="hmisc"){
        ##Extract the m data imputed for each variables
        ximp<-array(redata, dim=c(nrow(redata),ncol(redata),Moy))
        col<-1:ncol(redata)
        for(j in 1:ncol(redata)){
          if(sum(is.na(redata[,j]))==0){
            col<-col[-which(col==j)]
            next
          }
        }
        for(m in 1:Mimp){
          for(g in col){
            ximp[,,m][!complete.cases(ximp[,,m][,g]),g]<-imp$imputed[[g]][,m]
          }
        }
        ##Averaged dataset
        ximp[,,Moy]<-apply(ximp[,,1:Mimp],c(1,2),mean)
        
      }
    }else{
      ##
      ##Warning messages
      cat("Error! You must indicate if you are using Mice, Amelia, missMDA, NORM, or Hmisc package","\n")
    }}else{
      ## Warning messages
      cat("There is no missing value in your dataset","\n")
    }
  #return(ximp)
  tabM<-ximp[,,Moy]
  colnames(tabM)<-colnames(redata)
  list("ImpM"=tabM,"Mi"=ximp[,,1:Mimp],"nbMI"=Mimp, "missing"=as.data.frame(redata))
}#End
###
##
##
##
##Function to draw confidence ellipses
ELLI<-function(x,y,conf=0.95,np)
{centroid<-apply(cbind(x,y),2,mean)
ang <- seq(0,2*pi,length=np)
z<-cbind(cos(ang),sin(ang))
radiuscoef<-qnorm((1-conf)/2, lower.tail=F)
vcvxy<-var(cbind(x,y))
r<-cor(x,y)
M1<-matrix(c(1,1,-1,1),2,2)
M2<-matrix(c(var(x), var(y)),2,2)
M3<-matrix(c(1+r, 1-r),2,2, byrow=T)
ellpar<-M1*sqrt(M2*M3/2)
t(centroid + radiuscoef * ellpar %*% t(z))}
##
##
##
##

plot.MI<-function(IM,symmetric=FALSE,DIM=c(1,2),scale=FALSE,web=FALSE,ellipses=TRUE,...){
  if(any(is.na(IM$ImpM)==TRUE))
  { cat("There is still missing values in the imputed dataset, please check your imputation")
    break
  }else{
    Mo<-IM$nbMI+1
    pcaM<-princomp(IM$ImpM)
    cpdimM<-as.matrix(pcaM$scores[,DIM])   
    opa<-array(cpdimM,dim=c(nrow(cpdimM),ncol(cpdimM),Mo)) 
    for(i in 1:IM$nbMI){
      pca<-princomp(IM$Mi[,,i])
      opa[,,i]<-as.matrix(pca$scores[,DIM])
    }
    if(symmetric==TRUE){
      for (i in 1:IM$nbMI+1){
        trace<-sum(opa[,,i]^2)
        opa[,,i]<-opa[,,i]/sqrt(trace) 
      }
    }
    ############################ Ordinary Procrustes Analysis (library(shapes))
    for(k in 1:IM$nbMI){
      analyse<-procOPA(opa[,,Mo],opa[,,k], reflect=TRUE)
      opa[,,k]<-analyse$Bhat
    }
    opa[,,Mo]<-analyse$Ahat
    ######################## Principal component explained variance
    pvar<-pcaM$sdev^2
    tot<-sum(pvar)
    valX<-pvar[DIM[1]]
    valY<-pvar[DIM[2]]
    valX<-round(valX*100/tot,digits=2)
    valY<-round(valY*100/tot, digits=2)
    ######################## Plot function
    op <- par(no.readonly=TRUE)
    if(scale==TRUE){
      plot(opa[,1,Mo],opa[,2,Mo], type="p", pch=3, col=c(as.factor(ifelse(complete.cases(IM$missing) ==T, 1, 5))),lwd=1,xlim=range(opa[,1,Mo]),ylim=range(opa[,1,Mo]),xlab=paste("DIM",DIM[1],valX,"%",sep=" "),ylab=paste("DIM",DIM[2],valY,"%",sep=" "))
    }
    if(scale==FALSE){
      plot(opa[,1,Mo],opa[,2,Mo], type="p", pch=3, col=c(as.factor(ifelse(complete.cases(IM$missing) ==T, 1, 5))),lwd=1,xlab=paste("DIM",DIM[1],valX,"%",sep=" "),ylab=paste("DIM",DIM[2],valY,"%",sep=" "))
    }
    title("MI effect on Multivariate Analysis", font.main=3, adj=1)
    ## Store row names
    NR<-IM$missing
    rownames(IM$missing)<-NULL
    ##
    if(ellipses==TRUE){                                      
      coul<-as.numeric(rownames(IM$missing[complete.cases(IM$missing),]))
      for (j in coul){
        lines(ELLI(opa[j,1,],opa[j,2,],np=Mo), col="black", lwd=1)}
      coul<-as.numeric(rownames(IM$missing[!complete.cases(IM$missing),]))
      for (j in coul){
        lines(ELLI(opa[j,1,],opa[j,2,],np=Mo), col="red", lwd=1)}
    }else{ points(opa[,1,],opa[,2,],cex=0.5) }
    if(web==TRUE){
      coul<-as.numeric(rownames(IM$missing[complete.cases(IM$missing),]))
      for (j in coul){ 
        for(f in 1:IM$nbMI){
          segments(opa[j,1,Mo],opa[j,2,Mo], opa[j,1,f],opa[j,2,f], col="black", lwd=1) }
      } 
      coul<-as.numeric(rownames(IM$missing[!complete.cases(IM$missing),]))
      for (j in coul){ 
        for(f in 1:IM$nbMI){
          segments(opa[j,1,Mo],opa[j,2,Mo], opa[j,1,f],opa[j,2,f], col="red", lwd=1)}
      } 
      points(opa[,1,],opa[,2,],cex=0.5) 
    } 
    nom<-rownames(NR)
    text(opa[,1,Mo],opa[,2,Mo],nom, pos=1)
    
    abline(h=0,v=0, lty=3)
    par(xpd=TRUE)  # Do not clip to the drawing area
    lambda <- .025
    legend(par("usr")[1], (1 + lambda) * par("usr")[4] - lambda * par("usr")[3],c("Complete", "Missing"), xjust = 0, yjust = 0,lwd=3, lty=1, col=c(par('fg'), 'red'))
    par(op)      
  }
}




 
# convert to dagitty and orint dag functions ----

##
bn_to_adjmatrix <- function(bn_obj) {
  edg <- as.data.frame(bn_obj$arcs)
  node_names <- names(bn_obj$nodes)
  ans_mat <- matrix(
    data = 0, nrow = length(node_names),
    ncol = length(node_names),
    dimnames = list(node_names, node_names)
  )
  
  ans_mat[as.matrix(edg[c("from", "to")])] <- 1
  return(ans_mat)
}
###
adjmatrix_to_dagitty <- function(adjmatrix) {
  if (is.null(rownames(adjmatrix)) | is.null(colnames(adjmatrix)) | !identical(rownames(adjmatrix), colnames(adjmatrix))) {
    warning("Matrix column names or rownames are either missing or not compatible. They will be replaced by numeric node names")
    nodes <- 1:nrow(adjmatrix)
  } else {
    nodes <- rownames(adjmatrix)
  }
  
  from_to <- which(adjmatrix == 1, arr.ind = T)
  
  dag_string <- paste0(
    "dag { \n",
    paste0(nodes, collapse = "\n"),
    "\n",
    paste0(apply(from_to, 1, function(x) paste0(nodes[x[1]], " -> ", nodes[x[2]])),
           collapse = "\n"
    ),
    "\n } \n"
  )
  return(dagitty:::dagitty(dag_string))
}

##
causal_direction <- function(vec_1, vec_2, continuous_thresh, discrete_thresh) {
  if (class(vec_1) == "character") vec_1 <- factor(vec_1)
  if (class(vec_2) == "character") vec_2 <- factor(vec_2)
  y_cond_x <- function(x, y) {
    ans <- sapply(levels(x), function(x_val) {
      table(y[x == x_val]) / sum(x == x_val)
    })
    ans[is.nan(ans)] <- 0
    ans
  }
  if (class(vec_1) == "factor" & class(vec_2) == "numeric"){ 
    vec_2 <- factor(infotheo::discretize(vec_2)$X)
  }
  if (class(vec_1) == "numeric" & class(vec_2) == "factor"){ 
    vec_1 <- factor(infotheo::discretize(vec_1)$X)
  }
  if (class(vec_1) == "factor" & class(vec_2) == "factor") {
    p_vec_2_given_vec1 <- y_cond_x(x = vec_1, y = vec_2)
    p_vec_1 <- table(vec_1) / length(vec_1)
    dist_vec_1_causes_vec_2 <- energy:::dcor(p_vec_1, t(p_vec_2_given_vec1))
    
    p_vec_1_given_vec2 <- y_cond_x(x = vec_2, y = vec_1)
    p_vec_2 <- table(vec_2) / length(vec_2)
    dist_vec_2_causes_vec_1 <- energy:::dcor(p_vec_2, t(p_vec_1_given_vec2))
    
    if (dist_vec_2_causes_vec_1 - dist_vec_1_causes_vec_2 > discrete_thresh) {
      return("vec 1 causes vec 2")
    } else if(dist_vec_1_causes_vec_2 - dist_vec_2_causes_vec_1 > discrete_thresh){
      return("vec 2 causes vec 1")
    } else {
      return("not sure")
    }
  } else {
    cause_sum <- as.numeric(generalCorr:::some0Pairs(data.frame(vec_1, vec_2), verbo = F)$outVote[7])
    if (cause_sum > continuous_thresh) {
      return("vec 1 causes vec 2")
    } else if (cause_sum < -continuous_thresh){
      return("vec 2 causes vec 1")
    } else {
      return("not sure")
    }
  }
}
##
orient_dag <- function(adjmatrix, x, max_continuous_pairs_sample = 5000, continuous_thresh = 1, discrete_thresh = 0.3) {
  if (!is.matrix(adjmatrix)) {
    stop("Input DAG must be represented as adjacency matrix")
  } else {
    DAG_rownames <- rownames(adjmatrix)
    DAG_colnames <- colnames(adjmatrix)
    if (!identical(DAG_rownames, DAG_colnames)) {
      stop("DAG adjacency matrix rownames and colnames must be identical")
    }
    if (mean(DAG_rownames %in% names(x)) < 1) {
      stop("Some nodes are missing from the input data x")
    }
  }
  
  edges <- which(adjmatrix == 1, arr.ind = T)
  i = 1
  while(i <= nrow(edges)){
    dup_idx <- integer(0)
    dup_idx <- which(apply(edges[, c(2,1)], 1, function(x) x[1] == edges[i, 1] & x[2] == edges[i, 2]))
    if(length(dup_idx) == 1) {
      adjmatrix[edges[dup_idx, 1], edges[dup_idx, 2]] <- 0 # remove one of the duplicates
      edges <- edges[-dup_idx, ]
    }
    vec_1 <- x[[DAG_rownames[edges[i, 1]]]]
    vec_2 <- x[[DAG_rownames[edges[i, 2]]]]
    if (class(vec_1) == "numeric" & class(vec_2) == "numeric"){
      if(is.null(max_continuous_pairs_sample)){
        next # dont change orientation
      } else {
        samples <- sample.int(length(vec_1), min(max_continuous_pairs_sample, length(vec_1)))
        vec_1 <- vec_1[samples]
        vec_2 <- vec_2[samples]
      }
    } 
    
    cause <- causal_direction(vec_1, vec_2, 
                              continuous_thresh = ifelse(length(dup_idx) == 1, 0, continuous_thresh), # if bi-directed take whichever has higher score
                              discrete_thresh = ifelse(length(dup_idx) == 1, 0, discrete_thresh) # if bi-directed take whichever has higher score)
    )
    if (cause == "vec 1 causes vec 2") { 
      adjmatrix[edges[i, 1], edges[i, 2]] <- 1
      adjmatrix[edges[i, 2], edges[i, 1]] <- 0
    } else if(cause == "vec 2 causes vec 1"){
      adjmatrix[edges[i, 1], edges[i, 2]] <- 0
      adjmatrix[edges[i, 2], edges[i, 1]] <- 1
    }
    i <- i + 1
  }
  
  return(adjmatrix)
}





