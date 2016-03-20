library(httr)
library(XML)
library(plyr)
library(dtw)

## Generates the full list of permutations; scrounged from a Stack Overflow post
permutations <- function(x, prefix = c()){
    if(length(x) == 0 ) return(prefix)
    do.call(rbind, sapply(1:length(x), FUN = function(idx) permutations( x[-idx], c( prefix, x[idx])), simplify = FALSE))
}

## Determines the best mapping from the clusters that R come up with to the actual
## sector list 
bestSectorMapping <- function(actual_sectors, clusters){
    
    sectors <- unique(actual_sectors)
    sector_names <- unique(sectors)
    cat("Loading permutations...\n")
    sector_perm <- readRDS("permutations.rds")
    
    best_accuracy <- 0
    best_mapping <- character(length(sector_names))
    
    pb <- txtProgressBar(min = 1, max = nrow(sector_perm), width = 50, style = 3)
    
    cat("Beginning permutations...\n")
    for(i in 1:nrow(sector_perm)){
        perm <- sector_perm[i,]
        pred_sectors <- mapvalues(clusters, from = 1:length(unique(clusters)), to = sectors[perm])
        perm_accuracy <- sum(actual_sectors == pred_sectors)/length(actual_sectors)
        if(perm_accuracy > best_accuracy){
            best_accuracy <- perm_accuracy
            best_mapping <- sectors[perm]
        }
        setTxtProgressBar(pb, i)
    }
    
    return(list(best_mapping, best_accuracy))
}

## Gathers
gatherData <- function(){

    ## Get tickers & codes as of end of 2015
    wiki_html <- GET("https://en.wikipedia.org/w/index.php?title=List_of_S%26P_500_companies&oldid=697200065")
    tc <- content(wiki_html, as = "text")
    tab <- sub('.*(<table class="grid".*?>.*</table>).*', '\\1', tc)
    stock_table <- readHTMLTable(tab)[[2]]
    important <- data.frame(tickers = stock_table$`Ticker symbol`, sector = stock_table$`GICS Sector`)
    
    
    ## Grabbing all stocks with 252 entries for the year of 2015; seven of which - BXLT, CPGX, CSRA, HPE,
    ## KHC, WRK, and PYPL have less than 252 (range from 32-140), so those will be ignored
    ignore <- c("BXLT", "CPGX", "CSRA", "HPE", "KHC", "WRK", "PYPL")
    important <- important[!(important$tickers %in% ignore), ]
    tickers <- as.character(important$tickers)
    important$tickers <- as.character(important$tickers)
    important$sector <- as.character(important$sector)
    
    saveRDS(important, "important.rds")
    
    ## Need one stock to start it
    all_stocks <- getSymbols(tickers[1], auto.assign = FALSE)
    all_stocks <- all_stocks["2015"]
    
    for(tick in tickers[-1]){
        cat(tick, "\n")
        stock <- tryCatch(getSymbols(tick, auto.assign = FALSE), error = function(e){data.frame(a=numeric(0), b = numeric(0))})
        stock <- stock["2015"]
        all_stocks <- merge(all_stocks, stock)
    }
    
    all_stocks <- all_stocks[,grepl("Adjusted", names(all_stocks))]
    
    ## Get daily returns as percentages
    returns <- (all_stocks - lag(all_stocks, 1))/all_stocks
    returns <- returns[-1,]
    
    ## Strip the 'Adjusted' from the column names
    names(returns) <- substr(names(returns), 1, nchar(names(returns)) - 9)

    t_returns <- t(returns)
    saveRDS(t_returns, "returns.rds")

    p <- permutations(1:10)
    saveRDS(p, "permutations.rds")

}

## Example cycle for finding the sector mappings:
important <- readRDS("important.rds")
returns <- read.RDS("returns.rds")

distMatrix <- dist(returns, method = "correlation")
hc <- hclust(distMatrix, method = "ward.D")
memb <- cutree(hc, k=10)
table(memb)
bm <- bestSectorMapping(important$sector, memb)
