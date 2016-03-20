This is an experiment to see how several methods would attempt to cluster one year of return data for the S&P 500 stocks, and how closely those clusters would match the sector divisions in that index.  The data used is for the year of 2015, and the list of stocks that are being clustered is the listing as of December 31, 2015, according to Wikipedia.

This project can be broken down into three main problems:
* For the stocks on the S&P 500 as of December 31, 2015, get the sectors which they belong to and the daily returns for the year of 2015.
* Trying various combinations of distance metrics and clustering methods to see what clusterings arise.
* Checking which assignment of sector labels to the clusters gives the best accuracy.

For the first problem, the issue of daily returns was easy to handle, due to the easy access to historical end-of-day stock price data.  A list of the S&P 500 stocks at the end of the year was trickier, but was eventually found on the last edit in 2015 for the Wikipedia page listing the index's components.  Conveniently, this table also includes listings of which sector each stock belonged to.

The end-of-day data was compiled through the quantmod package's get.hist.quote() function, and then was manually transformed into daily percent returns using the adjusted close data.  Note that only stocks which had price data for the entirety of 2015 were used, which excluded seven stocks from the final data.

Extracting the Wikipedia data required using the httr library to get the raw HTML, followed by the XML library's readHTMLTable() function to pull the table out of the HTML and transfer it into a data frame.

Once all of this was assembled, return data was run through the dist() function (from the dtw library) in order to generate the distance or similarity measures between the time series  This output was then fed to the hclust() function to generate the necessary clusters.  A total of 21 tests were made, seven different distance/similarity measures for each of three different clustering methods.  An example of a sequence:

    distMatrix <- dist(returns, method = "correlation")
    hc <- hclust(distMatrix, method = "ward.D")
    predicted_clusters <- cutree(hc, k=10)
    bm <- bestSectorMapping(actual_sectors, predicted_clusters)

The bestSectorMapping function is a personally defined function that handles a problem with the setup: the fact that the predicted clusters are labeled 1 to 10, and don't match up to the sector labels in any way.  The function brute-forces a solution by comparing every possible mapping from the cluster labels to the sector labels, and seeing which mapping produces the highest accuracy.

The accuracies acquired from these tests are:

| dist \ hclust | complete | ward.D | ward.D2 |
| ------------- | -------: | -----: | ------: |
| chi-squared   | 0.177    | 0.179  | 0.181   |
| correlation   | 0.408    | 0.590  | 0.628   |
| cosine        | 0.414    | 0.414  | 0.618   |
| DTW           | 0.191    | 0.310  | 0.326   |
| euclidean     | 0.223    | 0.461  | 0.521   |
| manhattan     | 0.245    | 0.541  | 0.523   |
| Pearson       | 0.177    | 0.179  | 0.179   |

This is not a comprehensive analysis of the available distance/similarity and clustering methods; there are over 1000 possible combinations of them.

Note that the ones with the lowest accuracies are still around 18% accurate.  If you examine the clusterings for these, though, you will find that almost all of the elements end up in a single cluster; others have no more than 3 or 4 stocks, and usually just have one.  As such, these are essentially the counterpart to the 'lets guess the most frequent sector for everything' method of guessing in other circumstances.

Note that the ward.D clustering method outperforms the ward.D2 method.  According to <a href="http://arxiv.org/pdf/1111.6285.pdf">this</a> source, the primary difference between the two methods is that ward.D considers the weighted sum of squared distances between clusters, while ward.D2 considers the square root of the weighted sum of squared distances.  That additional square root appears to be the cause of the generally higher accuracy.

The conclusion to this is that trying to cluster one year's stock returns into sectors via R's clustering default clustering - along with some distance/similarity measures from the <TT>dtw</TT> library - seems difficult at best.