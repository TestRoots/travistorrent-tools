all.100.star.projects <- read.csv("ghtorrent_all_projects_100_stars.csv", header = F)
colnames(all.100.star.projects) <-  c('login','project','language','stars')
filtered.projects <- all.100.star.projects[all.100.star.projects$language %in% c("Java", "Ruby", "Go", "Python"),]
write.csv(filtered.projects, "java_ruby_python_go_projects_100_stars.csv", row.names = F)
filtered.projects$ghname <- paste(sep = "@", filtered.projects$login, filtered.projects$project)
write(filtered.projects$ghname, "plain_100_project_list.csv")
