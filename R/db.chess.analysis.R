working.dir <- '~/chessDB/';
dbfile <- 'chessAnalysis.db'

library("RSQLite")
drv <- dbDriver("SQLite")
con <- dbConnect(drv, dbfile);
chess.data <- dbGetQuery(con, "Select * from games where id=112")
aa<-apply(t(chess.data[,15:22]), 2, strsplit, ',')
