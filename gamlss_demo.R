library(wordbankr)
library(langcog)
library(tidyverse)
library(brms)
library(forcats)
library(survey)
library(gamlss)
theme_set(theme_mikabr())
font <- theme_mikabr()$text$family

# ------------ DATA PREP

# Read in Virginia temp data from SPSS
ws <- haven::read_sav("data/Web_WS_2007norming.sav") |>
  mutate(source = as_factor(sourcecat3way), 
         race = haven::as_factor(ethnicity), 
         sex = haven::as_factor(sex),
         sex = fct_recode(sex, Male = "M", Female = "F"),
         ethnicity = ifelse(as.character(child_hispanic_latino), 
                            "hispanic", "non-hispanic")) |>
  filter(Total_Produced <= 680, 
         !is.na(race), 
         !is.na(ethnicity))

# cut down the data to what we need
ws_minimal <- dplyr::select(ws, age,
                            Total_Produced, sex, race, ethnicity)

# ------------ WEIGHTING SECTION

# numbers somewhat sloppily scraped from from 2020 census
ws_unweighted <- svydesign(ids = ~1, data = ws_minimal)
race_dist <- data.frame(race = c("White", "Mixed/other", "Asian", 
                                 "Black", "No ethnicity reported"),
                        freq = nrow(ws_unweighted) * c(0.616, 0.188, .060, .124, 0.01))

ethnicity_dist <- data.frame(ethnicity = c("hispanic", "non-hispanic"),
                             freq = nrow(ws_unweighted) * c(0.187, 0.813))

# Here we use the rake function in the survey package to weight the current data by the population values for each of the variables included in the dataset.
ws_raked <- rake(design = ws_unweighted,
                 sample.margins = list(~race, ~ethnicity),
                 population.margins = list(race_dist, ethnicity_dist))


# Add these weights to the quantile regression.
ws_minimal$race_ethnicity_weights <- weights(ws_raked)

# ------------ PERCENTILE CURVES

# GAMLSS Sketch
ws_gam <- ws_minimal |>
  mutate(prop_produced = as.numeric(Total_Produced / 680), 
         race_ethnicity_weights = weights(ws_raked), 
         age = as.numeric(age)) |>
  filter(prop_produced < 1) 

gam_mod <- gamlss(prop_produced ~ pbm(age, lambda = 10000), 
                  sigma.formula = ~ pbm(age, lambda = 10000),
                  weights = race_ethnicity_weights,
                  family = BE,
                  data = ws_gam)

cents <- centiles.pred(gam_mod, cent = c(10, 25, 50, 75, 90), 
                       xname = "age", xvalues = 16:30) |>
  tibble() |>
  pivot_longer(2:6, names_to = "percentile", values_to = "pred")


ggplot(ws_gam, aes(x = age, y = prop_produced * 680)) + 
  geom_jitter(width = .2, alpha = .1) +
  geom_line(data = cents, aes(x = x, y = pred * 680, col = percentile)) +
  xlab("Age (months)") + 
  ylab("Proportion Producing") + 
  # theme(legend.position = "bottom") + 
  scale_color_solarized(name = "Percentile")


all_percentiles <- centiles.pred(gam_mod, cent = 1:99, 
                       xname = "age", xvalues = 16:30) |>
  tibble() |>
  rename(age = x) |>
  mutate(across(`1`:`99`, ~ round(.*680)))
