#! /usr/bin/Rscript

library(ggplot2);

# get directory
directory <- '/home/nharding/PGN_results/';


# read in all tables in directory.
files <- dir(directory, pattern="\\.txt$");
table.list <- lapply(files, read.table, sep="\t", header=TRUE, as.is = TRUE);
combined.data <- do.call(rbind, table.list);

# Preprocess: handle checkmates etc.
combined.data$date <- as.Date(combined.data$date, "%Y.%m.%d");
combined.data$diff <- with(combined.data, playedscore - bestscore);

combined.data$logblunder <- -log10(-combined.data$diff)


by(combined.data$diff, combined.data$player, summary)
table(player=combined.data$player, combined.data$diff==0)

# Calculate diff.
two.colour <- c("#CC6666", "#9999CC")
pdf("~/chess.pdf")
ggplot( combined.data, aes(x = date, y = logblunder, group = player, color = player)) + geom_line(alpha=0.5) + scale_color_manual(values=two.colour);
dev.off();
#+ geom_smooth(size=2, se=F) 

# By name do a simple summary
