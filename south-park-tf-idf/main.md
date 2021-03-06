---
title: "Going Down to South Park, Part 3: TF-IDF Analysis with R"
author: "Patrik Drhlik"
date: "November 27, 2018"
output: 
  html_document: 
    css: main.css
    fig_caption: yes
    keep_md: yes
---







*Do you think that it is possible to determine what a text document is about? Read on to see how to use R to programmatically discover main topics of several South Park seasons and episodes!*

In the [second article of the series](https://academy.vertabelo.com/blog/south-park-text-data-analysis-with-r-2/), I showed you how to use R to analyze differences between South Park characters. I assumed that Eric Cartman is the naughtiest character and proved it right or wrong. Check it out to see the conclusion.

In this last article of the series, you'll find out how to guess episode and season topics. I'll show you a very powerful tool that can help us describe what's going on across different documents. We'll be using data from my [southparkr](https://github.com/pdrhlik/southparkr) package again and the wonderful [tidytext](https://github.com/juliasilge/tidytext) package.

I'll include most of the code used to create all the tables and plots so that you can follow what's going on more easily. I'll start by setting up the data you'll be working with.


```r
# Color vectors for use in the plots
character_colors <- c("#F2F32A", "#ED304C", "#F36904", "#57B749", "#51B4BE", "#4F74B1")
vertabelo_color <- "#592a88"

# Data frame where each row is a word spoken by a charaacter
episode_words <- southparkr::process_episode_words(episode_lines, imdb_ratings, keep_stopwords = TRUE) %>%
	mutate(
		episode_number_str = str_glue("S{stringr::str_pad(season_number, 2, 'left', pad = '0')}E{stringr::str_pad(season_episode_number, 2, 'left', pad = '0')}"),
	)

# Data frame where each row is an episode summary
by_episode <- episode_words %>%
	group_by(episode_name) %>%
	summarize(
		total_words = n(),
		season_number = season_number[1],
		season_episode_number = season_episode_number[1],
		episode_number_str = episode_number_str[1],
		rating = user_rating[1],
		mean_sentiment_score = mean(sentiment_score, na.rm = TRUE)
	) %>%
	arrange(season_number, season_episode_number) %>%
	mutate(episode_order = 1:n())

# This step is needed to include the episode_order column in the episode_words data frame
episode_words <- left_join(
	episode_words,
	select(by_episode, season_number, season_episode_number, episode_order)
)
```

## So what is a tf–idf analysis?

I'll start by introducing the method we'll be using. **tf–idf** stands for **term frequency–inverse document frequency**. [Wikipedia offers](https://en.wikipedia.org/wiki/Tf%E2%80%93idf) a nice explanation: it is a numerical statistic that describes how a word is important in a certain document among a collection of documents.

Very common English words like *the*, *a*, *and*, etc. are probably contained in every text. If we were to simply count the number of occurrences of words, these would definitely be in the top.

Let's look at the top 10 occurring words in South Park overall to be sure.


```r
# Data frame with the 10 most frequent words in South Park
most_freq_words <- episode_words %>%
	count(word, sort = TRUE) %>%
	mutate(n = prettyNum(n, " ")) %>%
	head(10)
```

<table class="table" style="margin-left: auto; margin-right: auto;">
 <thead>
  <tr>
   <th style="text-align:left;"> Word </th>
   <th style="text-align:left;"> Number of occurrences </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;font-weight: bold;"> you </td>
   <td style="text-align:left;"> 28 277 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> the </td>
   <td style="text-align:left;"> 27 690 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> to </td>
   <td style="text-align:left;"> 22 228 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> i </td>
   <td style="text-align:left;"> 20 167 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> a </td>
   <td style="text-align:left;"> 17 326 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> and </td>
   <td style="text-align:left;"> 15 201 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> it </td>
   <td style="text-align:left;"> 11 218 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> is </td>
   <td style="text-align:left;"> 10 768 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> of </td>
   <td style="text-align:left;"> 10 658 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> we </td>
   <td style="text-align:left;"> 10 230 </td>
  </tr>
</tbody>
</table>

See? We were right. No words with a real meaning here that would tell us what the show is about.

A few examples are in order. Imagine a book author that has written several books. Each of the books will contain specific words to its plot that won't be present in the others. tf–idf will identify these specific words for us.

You will see it later on in action with South Park as well. Each episode clearly contains different dialog lines with different words. tf–idf will reveal the most important words for each episode. Because I know South Park very well, I will personally decide if it did a good job or not.

## But how does it work?

tf–idf penalizes words that appear a lot and in a large number of documents. It's actually a combination of two different metrics as the name suggests. The first one is called **term frequency**:

$$tf = \frac{number\ of\ term\ occurrences\ in\ a\ document}{total\ number\ of\ words\ in\ a\ document}$$

Simply put, it's the number of the word occurrences in a document. We will use the raw count divided by the total number of words in a document. The second one is called **inverse document frequency**:

$$idf = ln(\frac{n_{documents}}{n_{documents\ containing\ term}})$$

This statistic tells us if the word is rare or very common across the documents. If we have 287 episodes of South Park and all 287 of them contain a word **the**, then **idf** will become $idf = ln(\frac{287}{287})=ln(1)=0$. By combining their product together, we get **tf–idf**:

$$tf\_idf = tf * idf$$

Because of that, **tf–idf** will always be 0 for words that appear in every document.

Let's do a concrete example with a word **alien**. South Park episodes will be our documents. We will calculate the **term frequency** for each episode in which it appears. Its **inverse document frequency** will be a single number. The following table captures all of these results for each episode where the word **alien** appears.


```r
# Data frame of counts of "alien" word occurrences across episodes
alien <- filter(episode_words, word == "alien") %>%
	count(season_number, season_episode_number) %>%
	mutate(episode = glue("S{stringr::str_pad(season_number, 2, 'left', pad = '0')}E{stringr::str_pad(season_episode_number, 2, 'left', pad = '0')}")) %>%
	select(episode, n_alien = n) %>%
	left_join(
		by_episode %>% select(episode_number_str, total_words),
		by = c("episode" = "episode_number_str")) %>%
	# Calculating term frequency
	mutate(tf = n_alien / total_words)

# Wrangling alien to include idf and tf_idf columns
alien <- mutate(
	alien,
	# Calculating inverse document frequency
	idf = log(nrow(by_episode) / nrow(alien)),
	# Calculating term frequency–inverse document frequency
	tf_idf = tf * idf
)
```

<table class="table" style="margin-left: auto; margin-right: auto;">
 <thead>
  <tr>
   <th style="text-align:left;"> episode </th>
   <th style="text-align:right;"> n_alien </th>
   <th style="text-align:right;"> total_words </th>
   <th style="text-align:right;"> tf </th>
   <th style="text-align:right;"> idf </th>
   <th style="text-align:right;"> tf_idf </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S01E01 </td>
   <td style="text-align:right;"> 8 </td>
   <td style="text-align:right;"> 3234 </td>
   <td style="text-align:right;"> 0.0024737 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0071414 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S01E11 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 3165 </td>
   <td style="text-align:right;"> 0.0003160 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0009121 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S02E07 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 3100 </td>
   <td style="text-align:right;"> 0.0003226 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0009313 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S03E03 </td>
   <td style="text-align:right;"> 4 </td>
   <td style="text-align:right;"> 3861 </td>
   <td style="text-align:right;"> 0.0010360 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0029908 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S03E13 </td>
   <td style="text-align:right;"> 6 </td>
   <td style="text-align:right;"> 3005 </td>
   <td style="text-align:right;"> 0.0019967 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0057642 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S05E05 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 3991 </td>
   <td style="text-align:right;"> 0.0002506 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0007234 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S05E08 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 3390 </td>
   <td style="text-align:right;"> 0.0002950 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0008516 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S05E12 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 3429 </td>
   <td style="text-align:right;"> 0.0002916 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0008419 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S07E01 </td>
   <td style="text-align:right;"> 11 </td>
   <td style="text-align:right;"> 3225 </td>
   <td style="text-align:right;"> 0.0034109 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0098468 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S07E12 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 3692 </td>
   <td style="text-align:right;"> 0.0002709 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0007819 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S09E12 </td>
   <td style="text-align:right;"> 6 </td>
   <td style="text-align:right;"> 3339 </td>
   <td style="text-align:right;"> 0.0017969 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0051876 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S11E11 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 2811 </td>
   <td style="text-align:right;"> 0.0003557 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0010270 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S13E06 </td>
   <td style="text-align:right;"> 19 </td>
   <td style="text-align:right;"> 2859 </td>
   <td style="text-align:right;"> 0.0066457 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0191854 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S14E01 </td>
   <td style="text-align:right;"> 14 </td>
   <td style="text-align:right;"> 3026 </td>
   <td style="text-align:right;"> 0.0046266 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0133564 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S15E13 </td>
   <td style="text-align:right;"> 11 </td>
   <td style="text-align:right;"> 2947 </td>
   <td style="text-align:right;"> 0.0037326 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0107756 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> S20E01 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 3461 </td>
   <td style="text-align:right;"> 0.0002889 </td>
   <td style="text-align:right;"> 2.886893 </td>
   <td style="text-align:right;"> 0.0008341 </td>
  </tr>
</tbody>
</table>

We can see that the episode **S13E06** has the highest **tf–idf** for the word alien! It's called *Pinewood Derby* and Randy with his son Stan manage to make the first contact with alien life forms by accidentally discovering warp speed!

## Guessing topics of seasons 18, 19 and 20

I'd like to dive into analyzing three specific seasons. That's because seasons 18, 19 and 20 each have a plot that evolves throughout the episodes. This is something that the creators have rarely done before. Most of the episodes are stand-alone and don't require too much knowledge of the previous ones.

This is perfect for us because we should be able to use **tf–idf** to reveal what the seasons are about! You can imagine that it wouldn't be too meaningful for seasons where each episode has a different plot, right?

Let's examine the most significant words of these seasons in the following bar plot. The **tf–idf** x-axis values are multiplied by 1000 so that they are more readable.


```r
# Start by counting word occurrences in each season
season_words <- episode_words %>%
	count(season_number, word, sort = TRUE)

# Calculate a total number of words for each season
total_words <- season_words %>%
	group_by(season_number) %>%
	summarize(total = sum(n))

# Join both of the data frames and calculate tf-idf for each word in the season
season_words <- left_join(season_words, total_words) %>%
	# Automatically calculate tf-idf using bind_tf_idf from tidytext
	bind_tf_idf(word, season_number, n) %>%
	arrange(desc(tf_idf))

# Filtered data frame with only top 10 tf-idf words from seasons 18, 19 and 20
our_season_words <- season_words %>%
	filter(season_number %in% c(18, 19, 20)) %>%
	group_by(season_number) %>%
	top_n(10, wt = tf_idf) %>%
	arrange(season_number, desc(tf_idf))

# This is a slightly modified our_season_words data frame which
# is needed in order to properly display the following bar plot.
top_n_season_words <- our_season_words %>%
	arrange(desc(n)) %>%
	group_by(season_number) %>%
	top_n(10) %>%
	ungroup() %>%
	arrange(season_number, tf_idf) %>%
	# This is needed for proper bar ordering in facets
	# https://drsimonj.svbtle.com/ordering-categories-within-ggplot2-facets
	mutate(order = row_number())

# Code to produce the following bar plot
ggplot(top_n_season_words, aes(order, tf_idf*1000, fill = factor(season_number))) +
	geom_col(show.legend = FALSE) +
	facet_wrap(~ season_number, scales = "free") +
	coord_flip() +
	labs(
		y = "tf-idf * 1000",
		x = "Top 10 most significant season topics"
	) +
	scale_x_continuous(
		breaks = top_n_season_words$order,
		labels = top_n_season_words$word
	) +
	scale_fill_manual(values = character_colors[c(2, 4, 6)]) +
	theme(panel.grid.minor = element_blank())
```

![](main_files/figure-html/seasons_18_19_80-1.png)<!-- -->

The storyline of [season 18](https://southpark.wikia.com/wiki/Season_Eighteen#Storyline) is focused on Randy Marsh having a musical career and calls himself **Lorde**. That's a number one word on our list, great job! They also make fun of **gluten**-free diets throughout the season. A big focus is also on everything revolving around **virtual** reality.

[Season 19](https://southpark.wikia.com/wiki/Season_Nineteen#Storyline) has even stronger messages. It begins with an announcement that there will be a new principle–**PC Principal**. He starts promoting a **PC** (politically correct) culture because South Park is obviously full of racists and intolerant people. Mr. Garrison doesn't take it anymore and starts running for a president with his running mate **Caitlyn Jenner**, a former decathlon Olympic champion, Bruce Jenner who had a sex change operation. The last important topic of the series are **ads** that negatively influence everything and even start being indistinguishable from regular people.

In [season 20](https://southpark.wikia.com/wiki/Season_Twenty#Storyline), it was all about **SkankHunt42**, Kyle's dad. He became a **troll** that enjoyed harassing all sort of people online. It ended up with a **Danish** Olympic champion (fictional) Freja Ollegard by killing herself. **Denmark** then created a worldwide service called **trolltrace.com** that was able to identify any **troll** online. Eric Cartman also started dating with Heidi Turner and tried to get to **Mars** with the help of Elon Musk's SpaceX company.

If you compare the bold words with the ones in the bar plot; you'll see that **tf–idf** did a great job with the topic identification! There were also a few words that were picked up but I haven't mentioned them. Those were mostly words that were very significant in a single episode and made it to the top 10 anyway. For example **drones** or **handicar**. Each of these words appeared in a single episode very heavily. But overall, the method did a great job!

For the sake of completeness, take a look at the next bar plot that will show you the most significant topic for each season. Just keep in mind that it doesn't have to be true for the other seasons that we haven't analyzed that closely.


```r
# Summary data frame with each row being a top tf-idf word in a season
seasons_tf_idf <- season_words %>%
	group_by(season_number) %>%
	summarize(
		tf_idf = max(tf_idf),
		word = word[which.max(tf_idf)]
	)

# Code to produce the following plot
ggplot(seasons_tf_idf, aes(season_number, tf_idf, label = word)) +
	geom_col(fill = vertabelo_color) +
	geom_text(aes(y = 0), col = "white", hjust = -.05) +
	scale_x_continuous(breaks = 1:21) +
	labs(
		x = "Season number",
		y = "tf-idf"
	) +
	coord_flip() +
	theme(panel.grid.minor = element_blank())
```

![](main_files/figure-html/season_topics_plot-1.png)<!-- -->

## What are the 3 most popular episodes about?

I'll do the same plot I did for the three seasons but for the 3 most popular episodes according to IMDB. Because episodes generally have a single main theme, the results should be more accurate. Well, let's find out!


```r
# This code block is very similar to the one above that
# created the top 10 tf-idf words for the three seasons.
# Instead, it shows the top 10 tf-idf words for 3 most
# popular South Park episodes.

ep_words <- episode_words %>%
	count(episode_order, word, sort = TRUE)

ep_total_words <- ep_words %>%
	group_by(episode_order) %>%
	summarize(total = sum(n))

ep_words <- left_join(ep_words, ep_total_words) %>%
	 bind_tf_idf(word, episode_order, n) %>%
	 arrange(desc(tf_idf))

eps_tf_idf <- ep_words %>%
	group_by(episode_order) %>%
	summarize(
		tf_idf = max(tf_idf),
		word = word[which.max(tf_idf)]
	)

top_episodes <- ep_words %>%
	group_by(episode_order) %>%
	top_n(10, wt = tf_idf) %>%
	arrange(episode_order, desc(tf_idf)) %>%
	filter(episode_order %in% c(69, 147, 92))

top_n_episode_words <- top_episodes %>%
	arrange(desc(n)) %>%
	group_by(episode_order) %>%
	top_n(10) %>%
	ungroup() %>%
	arrange(episode_order, tf_idf) %>%
	# This is needed for proper bar ordering in facets
	# https://drsimonj.svbtle.com/ordering-categories-within-ggplot2-facets
	mutate(order = row_number())

ggplot(top_n_episode_words, aes(order, tf_idf*100, fill = factor(episode_order, labels = c("Scott Tenorman Must Die", "The Return of the Fellowship of the Ring to the Two Towers", "Make Love, Not Warcraft")))) +
	geom_col(show.legend = FALSE) +
	facet_wrap(~ factor(episode_order, labels = c("Scott Tenorman Must Die", "The Return of the\n Fellowship of the Ring \nto the Two Towers", "Make Love, Not Warcraft")), scales = "free") +
	coord_flip() +
	labs(
		y = "tf-idf * 100",
		x = "Top 10 most significant episode topics"
	) +
	scale_x_continuous(
		breaks = top_n_episode_words$order,
		labels = top_n_episode_words$word
	) +
	scale_fill_manual(values = character_colors[c(2, 4, 6)]) +
	theme(panel.grid.minor = element_blank())
```

![](main_files/figure-html/episode_tf_idf-1.png)<!-- -->

I'll try to describe each of the three episodes using a few sentences with its true storyline. **Beware! Spoilers ahead!**

**Scott Tenorman Must Die**: **Scott Tenorman**, a 9th-grader, sells his **pubes** to Eric Cartman. Eric realises later on that he got tricked and wants to get back at Scott. He trains Mr. **Denskins's** **pony** to **bite** off Scott's wiener. Eric ends up having Scott's parents killed and serves them to Scott in a **chilli** con carne on a chilli festival. The episode ends with Scott's favorite band, **Radiohead** coming to the festival and mocking Scott.

**The Return of the Fellowship of the Ring to the Two Towers**: Stan's parents rent a **porno videotape** called **Backdoor** sl\*\*s 9 and **The Lord of the Rings**. The boys are given a **quest** to deliver the LOTR movie to Butters. The two tapes got mixed though and Butters is given the **porno** tape instead.

**Make Love, Not Warcraft**: The boys play World of **Warcraft** but encounter a **player** that is even stronger than the **admins** who starts killing innocent **players**. Their only way to level up to fight the bully **character** is to start killing **computer** generated **boars**. Once they evolve their **characters** enough, their only chance is to use the **sword of the thousand truths** to win the fight!

If you know these episodes, you must agree with these amazing results! Let's end this section with an overview of main topics for each episode. You can explore the results on the following interactive plot. I put the IMDB ratings on the y-axis so that you can only explore the popular episodes if you wanted.


```r
# Wrangled by_episode data frame that includes the top tf-idf
# word for each episode.
by_episode <- inner_join(by_episode, eps_tf_idf) %>%
	mutate(text_hover = str_glue("Episode name: {episode_name}
					Episode number: {episode_number_str}
					IMDB rating: {rating}
					Characteristic word: {word}"))
# Creating the following plot
g <- ggplot(by_episode, aes(episode_order, rating)) +
	geom_point(aes(text = text_hover), alpha = 0.6, size = 3, col = vertabelo_color) +
	labs(
		x = "Episode number",
		y = "IMDB rating"
	)
# Making the following plot interactive
ggplotly(g, tooltip = "text")
```

<!--html_preserve--><div id="htmlwidget-922efb24b9b15a2e2aa0" style="width:672px;height:480px;" class="plotly html-widget"></div>
<script type="application/json" data-for="htmlwidget-922efb24b9b15a2e2aa0">{"x":{"data":[{"x":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,281,282,283,284,285,286,287],"y":[8.2,7.9,7.9,7.8,7.7,8.2,8.5,8.2,8.3,8.1,8.1,7.8,8.7,6.6,8.5,8.2,8.2,7.9,7.8,7.6,7.7,7.8,8.1,7.8,8.1,7.8,8,8.6,8.2,8.5,8.1,8.5,8.3,8.1,6.7,7.8,8.4,8.1,8.2,7.6,8,8.8,8.1,8.2,8.4,7.4,8,8.2,8.3,8.7,8.3,7.5,9,8.2,8.3,8.2,8.4,8.4,8.2,8.2,7.9,7,8.6,8.8,7.6,8.5,8.4,8.4,9.6,7.2,8.9,8.6,8.4,8,8.1,8.3,8.2,8.9,8.9,8.2,8.4,8.1,8.1,8.2,8.6,8.9,8.3,8.4,8.3,8.6,8.8,9.3,8.8,8.7,8.6,8.1,8.5,8.2,8.4,8.2,8.5,8.6,7.7,8.3,9,8.3,9.2,8.9,8.1,8.5,7.8,9.1,8.5,8.7,8.2,9.2,8.7,8.4,8.5,8.7,8.4,8.4,8.6,8.6,9.1,7.7,8.8,7.5,8.7,8.7,9.1,7.7,8.6,8.8,8,8.8,9.1,8.2,7.9,8.2,8.2,8.8,8.8,6.4,8,9,9.5,8.3,8.5,8.1,8.7,8.7,7.4,8.8,8.8,8,8.3,8.3,7.9,8.8,8.9,8,9,9,9,8.4,8.5,7.9,7,8.7,8,7.7,8.6,8.4,7.9,8.6,8.1,7.9,7.8,7.8,7.9,8.2,8.4,8.6,6.5,8.8,7.9,8.2,7.8,8.7,8.3,8.3,8.2,8.2,7.7,7.6,8,8.7,8.8,8.8,8.7,6.9,7.6,8,8.1,8.2,8.4,8.4,8.2,7.6,6.3,6.8,8,7.5,8,8.6,8.1,8.1,7.6,7.9,7.8,7.4,8,7.8,7.9,7.3,6.7,7.6,6.8,8.1,7.5,8.2,8.3,6.6,8.3,7.3,7.5,7.5,8.1,7.8,6.9,7.3,7.8,8.9,8.8,8.8,8.5,7.8,7.8,8.6,7.4,8,8.3,9.1,8.4,7.5,6.9,7.8,8.3,7.7,8.1,8.5,8,8.4,9,8.2,8,8,8.2,8.2,8,7.4,7.5,7.1,7.5,7.5,7,6.6,7.9,7.7,7.3,7.4,7.3,7.4,7.2,7.9,7.1],"text":["Episode name: Cartman Gets an Anal Probe<br />Episode number: S01E01<br />IMDB rating: 8.2<br />Characteristic word: moo","Episode name: Weight Gain 4000<br />Episode number: S01E02<br />IMDB rating: 7.9<br />Characteristic word: kathie","Episode name: Volcano<br />Episode number: S01E03<br />IMDB rating: 7.9<br />Characteristic word: scuzzlebutt","Episode name: Big Gay Al's Big Gay Boat Ride<br />Episode number: S01E04<br />IMDB rating: 7.8<br />Characteristic word: sparky","Episode name: An Elephant Makes Love to a Pig<br />Episode number: S01E05<br />IMDB rating: 7.7<br />Characteristic word: elephant","Episode name: Death<br />Episode number: S01E06<br />IMDB rating: 8.2<br />Characteristic word: grandpa","Episode name: Pinkeye<br />Episode number: S01E07<br />IMDB rating: 8.5<br />Characteristic word: costume","Episode name: Starvin' Marvin<br />Episode number: S01E08<br />IMDB rating: 8.2<br />Characteristic word: marvin","Episode name: Mr. Hankey, the Christmas Poo<br />Episode number: S01E09<br />IMDB rating: 8.3<br />Characteristic word: hankey","Episode name: Damien<br />Episode number: S01E10<br />IMDB rating: 8.1<br />Characteristic word: mega","Episode name: Tom's Rhinoplasty<br />Episode number: S01E11<br />IMDB rating: 8.1<br />Characteristic word: ellen","Episode name: Mecha-Streisand<br />Episode number: S01E12<br />IMDB rating: 7.8<br />Characteristic word: triangle","Episode name: Cartman's Mom is a Dirty Slut<br />Episode number: S01E13<br />IMDB rating: 8.7<br />Characteristic word: stupidest","Episode name: Terrance and Phillip in Not Without My Anus<br />Episode number: S02E01<br />IMDB rating: 6.6<br />Characteristic word: terrance","Episode name: Cartman's Mom is Still a Dirty Slut<br />Episode number: S02E02<br />IMDB rating: 8.5<br />Characteristic word: sail","Episode name: Chickenlover<br />Episode number: S02E03<br />IMDB rating: 8.2<br />Characteristic word: barbrady","Episode name: Ike's Wee Wee<br />Episode number: S02E04<br />IMDB rating: 8.2<br />Characteristic word: bris","Episode name: Conjoined Fetus Lady<br />Episode number: S02E05<br />IMDB rating: 7.9<br />Characteristic word: dodgeball","Episode name: The Mexican Staring Frog of Southern Sri Lanka<br />Episode number: S02E06<br />IMDB rating: 7.8<br />Characteristic word: ned","Episode name: City on the Edge of Forever<br />Episode number: S02E07<br />IMDB rating: 7.6<br />Characteristic word: crabtree","Episode name: Summer Sucks<br />Episode number: S02E08<br />IMDB rating: 7.7<br />Characteristic word: snake","Episode name: Chef's Chocolate Salty Balls<br />Episode number: S02E09<br />IMDB rating: 7.8<br />Characteristic word: hankey","Episode name: Chickenpox<br />Episode number: S02E10<br />IMDB rating: 8.1<br />Characteristic word: chickenpox","Episode name: Roger Ebert Should Lay off the Fatty Foods<br />Episode number: S02E11<br />IMDB rating: 7.8<br />Characteristic word: planetarium","Episode name: Clubhouses<br />Episode number: S02E12<br />IMDB rating: 8.1<br />Characteristic word: clubhouse","Episode name: Cow Days<br />Episode number: S02E13<br />IMDB rating: 7.8<br />Characteristic word: bull","Episode name: Chef Aid<br />Episode number: S02E14<br />IMDB rating: 8<br />Characteristic word: chef","Episode name: Spookyfish<br />Episode number: S02E15<br />IMDB rating: 8.6<br />Characteristic word: hella","Episode name: Merry Christmas Charlie Manson!<br />Episode number: S02E16<br />IMDB rating: 8.2<br />Characteristic word: manson","Episode name: Gnomes<br />Episode number: S02E17<br />IMDB rating: 8.5<br />Characteristic word: underpants","Episode name: Prehistoric Ice Man<br />Episode number: S02E18<br />IMDB rating: 8.1<br />Characteristic word: gorak","Episode name: Rainforest Shmainforest<br />Episode number: S03E01<br />IMDB rating: 8.5<br />Characteristic word: rainforest","Episode name: Spontaneous Combustion<br />Episode number: S03E02<br />IMDB rating: 8.3<br />Characteristic word: combustion","Episode name: The Succubus<br />Episode number: S03E03<br />IMDB rating: 8.1<br />Characteristic word: fitty","Episode name: Jakovasaurs<br />Episode number: S03E04<br />IMDB rating: 6.7<br />Characteristic word: jakov","Episode name: Tweek vs. Craig<br />Episode number: S03E05<br />IMDB rating: 7.8<br />Characteristic word: richard","Episode name: Sexual Harassment Panda<br />Episode number: S03E06<br />IMDB rating: 8.4<br />Characteristic word: panda","Episode name: Cat Orgy<br />Episode number: S03E07<br />IMDB rating: 8.1<br />Characteristic word: wicky","Episode name: Two Guys Naked in a Hot Tub<br />Episode number: S03E08<br />IMDB rating: 8.2<br />Characteristic word: bosley","Episode name: Jewbilee<br />Episode number: S03E09<br />IMDB rating: 7.6<br />Characteristic word: squirts","Episode name: Korn's Groovy Pirate Ghost Mystery<br />Episode number: S03E10<br />IMDB rating: 8<br />Characteristic word: pirate","Episode name: Chinpokomon<br />Episode number: S03E11<br />IMDB rating: 8.8<br />Characteristic word: chinpokomon","Episode name: Hooked on Monkey Fonics<br />Episode number: S03E12<br />IMDB rating: 8.1<br />Characteristic word: rebecca","Episode name: Starvin' Marvin in Space<br />Episode number: S03E13<br />IMDB rating: 8.2<br />Characteristic word: marklar","Episode name: The Red Badge of Gayness<br />Episode number: S03E14<br />IMDB rating: 8.4<br />Characteristic word: reenactment","Episode name: Mr. Hankey's Christmas Classics<br />Episode number: S03E15<br />IMDB rating: 7.4<br />Characteristic word: dreidel","Episode name: Are You There God? It's Me, Jesus<br />Episode number: S03E16<br />IMDB rating: 8<br />Characteristic word: period","Episode name: World Wide Recorder Concert<br />Episode number: S03E17<br />IMDB rating: 8.2<br />Characteristic word: mung","Episode name: The Tooth Fairy Tats 2000<br />Episode number: S04E01<br />IMDB rating: 8.3<br />Characteristic word: tooth","Episode name: Cartman's Silly Hate Crime 2000<br />Episode number: S04E02<br />IMDB rating: 8.7<br />Characteristic word: crime","Episode name: Timmy 2000<br />Episode number: S04E03<br />IMDB rating: 8.3<br />Characteristic word: timmy","Episode name: Quintuplets 2000<br />Episode number: S04E04<br />IMDB rating: 7.5<br />Characteristic word: romania","Episode name: Cartman Joins NAMBLA<br />Episode number: S04E05<br />IMDB rating: 9<br />Characteristic word: nambla","Episode name: Cherokee Hair Tampons<br />Episode number: S04E06<br />IMDB rating: 8.2<br />Characteristic word: kidney","Episode name: Chef Goes Nanners<br />Episode number: S04E07<br />IMDB rating: 8.3<br />Characteristic word: flag","Episode name: Something You Can Do with Your Finger<br />Episode number: S04E08<br />IMDB rating: 8.2<br />Characteristic word: fingerbang","Episode name: Do the Handicapped Go to Hell?<br />Episode number: S04E09<br />IMDB rating: 8.4<br />Characteristic word: huki","Episode name: Probably<br />Episode number: S04E10<br />IMDB rating: 8.4<br />Characteristic word: saddam","Episode name: Fourth Grade<br />Episode number: S04E11<br />IMDB rating: 8.2<br />Characteristic word: grade","Episode name: Trapper Keeper<br />Episode number: S04E12<br />IMDB rating: 8.2<br />Characteristic word: trapper","Episode name: Helen Keller! The Musical<br />Episode number: S04E13<br />IMDB rating: 7.9<br />Characteristic word: gobbles","Episode name: Pip<br />Episode number: S04E14<br />IMDB rating: 7<br />Characteristic word: pip","Episode name: Fat Camp<br />Episode number: S04E15<br />IMDB rating: 8.6<br />Characteristic word: prostitute","Episode name: The Wacky Molestation Adventure<br />Episode number: S04E16<br />IMDB rating: 8.8<br />Characteristic word: provider","Episode name: A Very Crappy Christmas<br />Episode number: S04E17<br />IMDB rating: 7.6<br />Characteristic word: christmas","Episode name: It Hits the Fan<br />Episode number: S05E01<br />IMDB rating: 8.5<br />Characteristic word: shit","Episode name: Cripple Fight<br />Episode number: S05E02<br />IMDB rating: 8.4<br />Characteristic word: scouts","Episode name: Super Best Friends<br />Episode number: S05E03<br />IMDB rating: 8.4<br />Characteristic word: blaine","Episode name: Scott Tenorman Must Die<br />Episode number: S05E04<br />IMDB rating: 9.6<br />Characteristic word: scott","Episode name: Terrance and Phillip: Behind the Blow<br />Episode number: S05E05<br />IMDB rating: 7.2<br />Characteristic word: phillip","Episode name: Cartmanland<br />Episode number: S05E06<br />IMDB rating: 8.9<br />Characteristic word: cartmanland","Episode name: Proper Condom Use<br />Episode number: S05E07<br />IMDB rating: 8.6<br />Characteristic word: condom","Episode name: Towelie<br />Episode number: S05E08<br />IMDB rating: 8.4<br />Characteristic word: towel","Episode name: Osama bin Laden Has Farty Pants<br />Episode number: S05E09<br />IMDB rating: 8<br />Characteristic word: afghanistan","Episode name: How to Eat with Your Butt<br />Episode number: S05E10<br />IMDB rating: 8.1<br />Characteristic word: milk","Episode name: The Entity<br />Episode number: S05E11<br />IMDB rating: 8.3<br />Characteristic word: cousin","Episode name: Here Comes the Neighborhood<br />Episode number: S05E12<br />IMDB rating: 8.2<br />Characteristic word: rich","Episode name: Kenny Dies<br />Episode number: S05E13<br />IMDB rating: 8.9<br />Characteristic word: stem","Episode name: Butters' Very Own Episode<br />Episode number: S05E14<br />IMDB rating: 8.9<br />Characteristic word: bennigan's","Episode name: Jared Has Aides<br />Episode number: S06E01<br />IMDB rating: 8.2<br />Characteristic word: aides","Episode name: Asspen<br />Episode number: S06E02<br />IMDB rating: 8.4<br />Characteristic word: montage","Episode name: Freak Strike<br />Episode number: S06E03<br />IMDB rating: 8.1<br />Characteristic word: maury","Episode name: Fun with Veal<br />Episode number: S06E04<br />IMDB rating: 8.1<br />Characteristic word: veal","Episode name: The New Terrance and Phillip Movie Trailer<br />Episode number: S06E05<br />IMDB rating: 8.2<br />Characteristic word: tugger","Episode name: Professor Chaos<br />Episode number: S06E06<br />IMDB rating: 8.6<br />Characteristic word: chaos","Episode name: The Simpsons Already Did It<br />Episode number: S06E07<br />IMDB rating: 8.9<br />Characteristic word: simpsons","Episode name: Red Hot Catholic Love<br />Episode number: S06E08<br />IMDB rating: 8.3<br />Characteristic word: vatican","Episode name: Free Hat<br />Episode number: S06E09<br />IMDB rating: 8.4<br />Characteristic word: hat","Episode name: Bebe's Boobs Destroy Society<br />Episode number: S06E10<br />IMDB rating: 8.3<br />Characteristic word: bebe","Episode name: Child Abduction is Not Funny<br />Episode number: S06E11<br />IMDB rating: 8.6<br />Characteristic word: rabble","Episode name: A Ladder to Heaven<br />Episode number: S06E12<br />IMDB rating: 8.8<br />Characteristic word: ladder","Episode name: The Return of the Fellowship of the Ring to the Two Towers<br />Episode number: S06E13<br />IMDB rating: 9.3<br />Characteristic word: rings","Episode name: The Death Camp of Tolerance<br />Episode number: S06E14<br />IMDB rating: 8.8<br />Characteristic word: lemmiwinks","Episode name: The Biggest Douche in the Universe<br />Episode number: S06E15<br />IMDB rating: 8.7<br />Characteristic word: edward","Episode name: My Future Self n' Me<br />Episode number: S06E16<br />IMDB rating: 8.6<br />Characteristic word: future","Episode name: Red Sleigh Down<br />Episode number: S06E17<br />IMDB rating: 8.1<br />Characteristic word: christmas","Episode name: Cancelled<br />Episode number: S07E01<br />IMDB rating: 8.5<br />Characteristic word: earthlings","Episode name: Krazy Kripples<br />Episode number: S07E02<br />IMDB rating: 8.2<br />Characteristic word: christopher","Episode name: Toilet Paper<br />Episode number: S07E03<br />IMDB rating: 8.4<br />Characteristic word: toilet","Episode name: I'm a Little Bit Country<br />Episode number: S07E04<br />IMDB rating: 8.2<br />Characteristic word: rabble","Episode name: Fat Butt and Pancake Head<br />Episode number: S07E05<br />IMDB rating: 8.5<br />Characteristic word: lopez","Episode name: Lil' Crime Stoppers<br />Episode number: S07E06<br />IMDB rating: 8.6<br />Characteristic word: detectives","Episode name: Red Man's Greed<br />Episode number: S07E07<br />IMDB rating: 7.7<br />Characteristic word: sars","Episode name: South Park is Gay!<br />Episode number: S07E08<br />IMDB rating: 8.3<br />Characteristic word: metrosexual","Episode name: Christian Rock Hard<br />Episode number: S07E09<br />IMDB rating: 9<br />Characteristic word: album","Episode name: Grey Dawn<br />Episode number: S07E10<br />IMDB rating: 8.3<br />Characteristic word: seniors","Episode name: Casa Bonita<br />Episode number: S07E11<br />IMDB rating: 9.2<br />Characteristic word: bonita","Episode name: All About Mormons<br />Episode number: S07E12<br />IMDB rating: 8.9<br />Characteristic word: dumb","Episode name: Butt Out<br />Episode number: S07E13<br />IMDB rating: 8.1<br />Characteristic word: tobacco","Episode name: Raisins<br />Episode number: S07E14<br />IMDB rating: 8.5<br />Characteristic word: raisins","Episode name: It's Christmas in Canada<br />Episode number: S07E15<br />IMDB rating: 7.8<br />Characteristic word: canada","Episode name: Good Times with Weapons<br />Episode number: S08E01<br />IMDB rating: 9.1<br />Characteristic word: ninja","Episode name: Up the Down Steroid<br />Episode number: S08E02<br />IMDB rating: 8.5<br />Characteristic word: timmah","Episode name: The Passion of the Jew<br />Episode number: S08E03<br />IMDB rating: 8.7<br />Characteristic word: mel","Episode name: You Got F'd in the A<br />Episode number: S08E04<br />IMDB rating: 8.2<br />Characteristic word: served","Episode name: AWESOM-O<br />Episode number: S08E05<br />IMDB rating: 9.2<br />Characteristic word: awesom","Episode name: The Jeffersons<br />Episode number: S08E06<br />IMDB rating: 8.7<br />Characteristic word: blanket","Episode name: Goobacks<br />Episode number: S08E07<br />IMDB rating: 8.4<br />Characteristic word: future","Episode name: Douche and Turd<br />Episode number: S08E08<br />IMDB rating: 8.5<br />Characteristic word: vote","Episode name: Something Wall-Mart This Way Comes<br />Episode number: S08E09<br />IMDB rating: 8.7<br />Characteristic word: mart","Episode name: Pre-School<br />Episode number: S08E10<br />IMDB rating: 8.4<br />Characteristic word: trent","Episode name: Quest for Ratings<br />Episode number: S08E11<br />IMDB rating: 8.4<br />Characteristic word: cough","Episode name: Stupid Spoiled Whore Video Playset<br />Episode number: S08E12<br />IMDB rating: 8.6<br />Characteristic word: paris","Episode name: Cartman's Incredible Gift<br />Episode number: S08E13<br />IMDB rating: 8.6<br />Characteristic word: psychic","Episode name: Woodland Critter Christmas<br />Episode number: S08E14<br />IMDB rating: 9.1<br />Characteristic word: antichrist","Episode name: Mr. Garrison's Fancy New Vagina<br />Episode number: S09E01<br />IMDB rating: 7.7<br />Characteristic word: dolphin","Episode name: Die Hippie, Die<br />Episode number: S09E02<br />IMDB rating: 8.8<br />Characteristic word: hippies","Episode name: Wing<br />Episode number: S09E03<br />IMDB rating: 7.5<br />Characteristic word: wing","Episode name: Best Friends Forever<br />Episode number: S09E04<br />IMDB rating: 8.7<br />Characteristic word: psp","Episode name: The Losing Edge<br />Episode number: S09E05<br />IMDB rating: 8.7<br />Characteristic word: strike","Episode name: The Death of Eric Cartman<br />Episode number: S09E06<br />IMDB rating: 9.1<br />Characteristic word: lu","Episode name: Erection Day<br />Episode number: S09E07<br />IMDB rating: 7.7<br />Characteristic word: jimmy","Episode name: Two Days Before the Day After Tomorrow<br />Episode number: S09E08<br />IMDB rating: 8.6<br />Characteristic word: dam","Episode name: Marjorine<br />Episode number: S09E09<br />IMDB rating: 8.8<br />Characteristic word: marjorine","Episode name: Follow That Egg!<br />Episode number: S09E10<br />IMDB rating: 8<br />Characteristic word: egg","Episode name: Ginger Kids<br />Episode number: S09E11<br />IMDB rating: 8.8<br />Characteristic word: ginger","Episode name: Trapped in the Closet<br />Episode number: S09E12<br />IMDB rating: 9.1<br />Characteristic word: hubbard","Episode name: Free Willzyx<br />Episode number: S09E13<br />IMDB rating: 8.2<br />Characteristic word: whale","Episode name: Bloody Mary<br />Episode number: S09E14<br />IMDB rating: 7.9<br />Characteristic word: ichi","Episode name: The Return of Chef!<br />Episode number: S10E01<br />IMDB rating: 8.2<br />Characteristic word: chef","Episode name: Smug Alert!<br />Episode number: S10E02<br />IMDB rating: 8.2<br />Characteristic word: smug","Episode name: Cartoon Wars Part I<br />Episode number: S10E03<br />IMDB rating: 8.8<br />Characteristic word: mohammad","Episode name: Cartoon Wars Part II<br />Episode number: S10E04<br />IMDB rating: 8.8<br />Characteristic word: mohammad","Episode name: A Million Little Fibers<br />Episode number: S10E05<br />IMDB rating: 6.4<br />Characteristic word: towel","Episode name: ManBearPig<br />Episode number: S10E06<br />IMDB rating: 8<br />Characteristic word: manbearpig","Episode name: Tsst<br />Episode number: S10E07<br />IMDB rating: 9<br />Characteristic word: tsst","Episode name: Make Love, Not Warcraft<br />Episode number: S10E08<br />IMDB rating: 9.5<br />Characteristic word: warcraft","Episode name: Mystery of the Urinal Deuce<br />Episode number: S10E09<br />IMDB rating: 8.3<br />Characteristic word: urinal","Episode name: Miss Teacher Bangs a Boy<br />Episode number: S10E10<br />IMDB rating: 8.5<br />Characteristic word: monitor","Episode name: Hell on Earth 2006<br />Episode number: S10E11<br />IMDB rating: 8.1<br />Characteristic word: smalls","Episode name: Go God Go<br />Episode number: S10E12<br />IMDB rating: 8.7<br />Characteristic word: wii","Episode name: Go God Go XII<br />Episode number: S10E13<br />IMDB rating: 8.7<br />Characteristic word: bark","Episode name: Stanley's Cup<br />Episode number: S10E14<br />IMDB rating: 7.4<br />Characteristic word: coach","Episode name: With Apologies to Jesse Jackson<br />Episode number: S11E01<br />IMDB rating: 8.8<br />Characteristic word: nigger","Episode name: Cartman Sucks<br />Episode number: S11E02<br />IMDB rating: 8.8<br />Characteristic word: picture","Episode name: Lice Capades<br />Episode number: S11E03<br />IMDB rating: 8<br />Characteristic word: lice","Episode name: The Snuke<br />Episode number: S11E04<br />IMDB rating: 8.3<br />Characteristic word: detonator","Episode name: Fantastic Easter Special<br />Episode number: S11E05<br />IMDB rating: 8.3<br />Characteristic word: rabbit","Episode name: D-Yikes!<br />Episode number: S11E06<br />IMDB rating: 7.9<br />Characteristic word: persians","Episode name: Night of the Living Homeless<br />Episode number: S11E07<br />IMDB rating: 8.8<br />Characteristic word: homeless","Episode name: Le Petit Tourette<br />Episode number: S11E08<br />IMDB rating: 8.9<br />Characteristic word: tourette's","Episode name: More Crap<br />Episode number: S11E09<br />IMDB rating: 8<br />Characteristic word: bono","Episode name: Imaginationland<br />Episode number: S11E10<br />IMDB rating: 9<br />Characteristic word: leprechaun","Episode name: Imaginationland, Episode II<br />Episode number: S11E11<br />IMDB rating: 9<br />Characteristic word: snarf","Episode name: Imaginationland, Episode III<br />Episode number: S11E12<br />IMDB rating: 9<br />Characteristic word: imaginary","Episode name: Guitar Queer-O<br />Episode number: S11E13<br />IMDB rating: 8.4<br />Characteristic word: hero","Episode name: The List<br />Episode number: S11E14<br />IMDB rating: 8.5<br />Characteristic word: list","Episode name: Tonsil Trouble<br />Episode number: S12E01<br />IMDB rating: 7.9<br />Characteristic word: hiv","Episode name: Britney's New Look<br />Episode number: S12E02<br />IMDB rating: 7<br />Characteristic word: britney","Episode name: Major Boobage<br />Episode number: S12E03<br />IMDB rating: 8.7<br />Characteristic word: cheesing","Episode name: Canada on Strike<br />Episode number: S12E04<br />IMDB rating: 8<br />Characteristic word: canada","Episode name: Eek, A Penis!<br />Episode number: S12E05<br />IMDB rating: 7.7<br />Characteristic word: penis","Episode name: Over Logging<br />Episode number: S12E06<br />IMDB rating: 8.6<br />Characteristic word: internet","Episode name: Super Fun Time<br />Episode number: S12E07<br />IMDB rating: 8.4<br />Characteristic word: pioneer","Episode name: The China Probrem<br />Episode number: S12E08<br />IMDB rating: 7.9<br />Characteristic word: chinese","Episode name: Breast Cancer Show Ever<br />Episode number: S12E09<br />IMDB rating: 8.6<br />Characteristic word: wendy","Episode name: Pandemic<br />Episode number: S12E10<br />IMDB rating: 8.1<br />Characteristic word: flute","Episode name: Pandemic 2: The Startling<br />Episode number: S12E11<br />IMDB rating: 7.9<br />Characteristic word: guinea","Episode name: About Last Night...<br />Episode number: S12E12<br />IMDB rating: 7.8<br />Characteristic word: obama","Episode name: Elementary School Musical<br />Episode number: S12E13<br />IMDB rating: 7.8<br />Characteristic word: bridon","Episode name: The Ungroundable<br />Episode number: S12E14<br />IMDB rating: 7.9<br />Characteristic word: vampire","Episode name: The Ring<br />Episode number: S13E01<br />IMDB rating: 8.2<br />Characteristic word: purity","Episode name: The Coon<br />Episode number: S13E02<br />IMDB rating: 8.4<br />Characteristic word: mysterion","Episode name: Margaritaville<br />Episode number: S13E03<br />IMDB rating: 8.6<br />Characteristic word: economy","Episode name: Eat, Pray, Queef<br />Episode number: S13E04<br />IMDB rating: 6.5<br />Characteristic word: queef","Episode name: Fishsticks<br />Episode number: S13E05<br />IMDB rating: 8.8<br />Characteristic word: fishsticks","Episode name: Pinewood Derby<br />Episode number: S13E06<br />IMDB rating: 7.9<br />Characteristic word: derby","Episode name: Fatbeard<br />Episode number: S13E07<br />IMDB rating: 8.2<br />Characteristic word: pirates","Episode name: Dead Celebrities<br />Episode number: S13E08<br />IMDB rating: 7.8<br />Characteristic word: mays","Episode name: Butters' Bottom Bitch<br />Episode number: S13E09<br />IMDB rating: 8.7<br />Characteristic word: pimp","Episode name: W.T.F.<br />Episode number: S13E10<br />IMDB rating: 8.3<br />Characteristic word: wrestling","Episode name: Whale Whores<br />Episode number: S13E11<br />IMDB rating: 8.3<br />Characteristic word: japanese","Episode name: The F Word<br />Episode number: S13E12<br />IMDB rating: 8.2<br />Characteristic word: fags","Episode name: Dances with Smurfs<br />Episode number: S13E13<br />IMDB rating: 8.2<br />Characteristic word: smurfs","Episode name: Pee<br />Episode number: S13E14<br />IMDB rating: 7.7<br />Characteristic word: pee","Episode name: Sexual Healing<br />Episode number: S14E01<br />IMDB rating: 7.6<br />Characteristic word: addiction","Episode name: The Tale of Scrotie McBoogerballs<br />Episode number: S14E02<br />IMDB rating: 8<br />Characteristic word: book","Episode name: Medicinal Fried Chicken<br />Episode number: S14E03<br />IMDB rating: 8.7<br />Characteristic word: kfc","Episode name: You Have 0 Friends<br />Episode number: S14E04<br />IMDB rating: 8.8<br />Characteristic word: facebook","Episode name: 200<br />Episode number: S14E05<br />IMDB rating: 8.8<br />Characteristic word: muhammad","Episode name: 201<br />Episode number: S14E06<br />IMDB rating: 8.7<br />Characteristic word: muhammad","Episode name: Crippled Summer<br />Episode number: S14E07<br />IMDB rating: 6.9<br />Characteristic word: towelie","Episode name: Poor and Stupid<br />Episode number: S14E08<br />IMDB rating: 7.6<br />Characteristic word: nascar","Episode name: It's a Jersey Thing<br />Episode number: S14E09<br />IMDB rating: 8<br />Characteristic word: jersey","Episode name: Insheeption<br />Episode number: S14E10<br />IMDB rating: 8.1<br />Characteristic word: hoarding","Episode name: Coon 2: Hindsight<br />Episode number: S14E11<br />IMDB rating: 8.2<br />Characteristic word: coon","Episode name: Mysterion Rises<br />Episode number: S14E12<br />IMDB rating: 8.4<br />Characteristic word: cthulhu","Episode name: Coon vs. Coon & Friends<br />Episode number: S14E13<br />IMDB rating: 8.4<br />Characteristic word: coon","Episode name: Creme Fraiche<br />Episode number: S14E14<br />IMDB rating: 8.2<br />Characteristic word: fraîche","Episode name: HUMANCENTiPAD<br />Episode number: S15E01<br />IMDB rating: 7.6<br />Characteristic word: apple","Episode name: Funnybot<br />Episode number: S15E02<br />IMDB rating: 6.3<br />Characteristic word: funnybot","Episode name: Royal Pudding<br />Episode number: S15E03<br />IMDB rating: 6.8<br />Characteristic word: decay","Episode name: T.M.I.<br />Episode number: S15E04<br />IMDB rating: 8<br />Characteristic word: inches","Episode name: Crack Baby Athletic Association<br />Episode number: S15E05<br />IMDB rating: 7.5<br />Characteristic word: crack","Episode name: City Sushi<br />Episode number: S15E06<br />IMDB rating: 8<br />Characteristic word: janus","Episode name: You're Getting Old<br />Episode number: S15E07<br />IMDB rating: 8.6<br />Characteristic word: tween","Episode name: Ass Burgers<br />Episode number: S15E08<br />IMDB rating: 8.1<br />Characteristic word: asperger's","Episode name: The Last of the Meheecans<br />Episode number: S15E09<br />IMDB rating: 8.1<br />Characteristic word: mantequilla","Episode name: Bass to Mouth<br />Episode number: S15E10<br />IMDB rating: 7.6<br />Characteristic word: lemmiwinks","Episode name: Broadway Bro Down<br />Episode number: S15E11<br />IMDB rating: 7.9<br />Characteristic word: blowjob","Episode name: 1%<br />Episode number: S15E12<br />IMDB rating: 7.8<br />Characteristic word: 99","Episode name: A History Channel Thanksgiving<br />Episode number: S15E13<br />IMDB rating: 7.4<br />Characteristic word: stuffing","Episode name: The Poor Kid<br />Episode number: S15E14<br />IMDB rating: 8<br />Characteristic word: penn","Episode name: Reverse Cowgirl<br />Episode number: S16E01<br />IMDB rating: 7.8<br />Characteristic word: toilet","Episode name: Cash For Gold<br />Episode number: S16E02<br />IMDB rating: 7.9<br />Characteristic word: jewelry","Episode name: Faith Hilling<br />Episode number: S16E03<br />IMDB rating: 7.3<br />Characteristic word: hilling","Episode name: Jewpacabra<br />Episode number: S16E04<br />IMDB rating: 6.7<br />Characteristic word: jewpacabra","Episode name: Butterballs<br />Episode number: S16E05<br />IMDB rating: 7.6<br />Characteristic word: bullying","Episode name: I Should Have Never Gone Ziplining<br />Episode number: S16E06<br />IMDB rating: 6.8<br />Characteristic word: ziplining","Episode name: Cartman Finds Love<br />Episode number: S16E07<br />IMDB rating: 8.1<br />Characteristic word: nichole","Episode name: Sarcastaball<br />Episode number: S16E08<br />IMDB rating: 7.5<br />Characteristic word: sarcastaball","Episode name: Raising the Bar<br />Episode number: S16E09<br />IMDB rating: 8.2<br />Characteristic word: boo","Episode name: Insecurity<br />Episode number: S16E10<br />IMDB rating: 8.3<br />Characteristic word: insecurity","Episode name: Going Native<br />Episode number: S16E11<br />IMDB rating: 6.6<br />Characteristic word: haoles","Episode name: A Nightmare on Face Time<br />Episode number: S16E12<br />IMDB rating: 8.3<br />Characteristic word: blockbuster","Episode name: A Scause For Applause<br />Episode number: S16E13<br />IMDB rating: 7.3<br />Characteristic word: bracelet","Episode name: Obama Wins!<br />Episode number: S16E14<br />IMDB rating: 7.5<br />Characteristic word: ballots","Episode name: Let Go, Let Gov<br />Episode number: S17E01<br />IMDB rating: 7.5<br />Characteristic word: dmv","Episode name: Informative Murder Porn<br />Episode number: S17E02<br />IMDB rating: 8.1<br />Characteristic word: minecraft","Episode name: World War Zimmerman<br />Episode number: S17E03<br />IMDB rating: 7.8<br />Characteristic word: zimmerman","Episode name: Goth Kids 3: Dawn of the Posers<br />Episode number: S17E04<br />IMDB rating: 6.9<br />Characteristic word: emo","Episode name: Taming Strange<br />Episode number: S17E05<br />IMDB rating: 7.3<br />Characteristic word: intellilink","Episode name: Ginger Cow<br />Episode number: S17E06<br />IMDB rating: 7.8<br />Characteristic word: yummy","Episode name: Black Friday<br />Episode number: S17E07<br />IMDB rating: 8.9<br />Characteristic word: friday","Episode name: A Song of Ass and Fire<br />Episode number: S17E08<br />IMDB rating: 8.8<br />Characteristic word: wiener","Episode name: Titties and Dragons<br />Episode number: S17E09<br />IMDB rating: 8.8<br />Characteristic word: kenni","Episode name: The Hobbit<br />Episode number: S17E10<br />IMDB rating: 8.5<br />Characteristic word: hobbit","Episode name: Go Fund Yourself<br />Episode number: S18E01<br />IMDB rating: 7.8<br />Characteristic word: redskins","Episode name: Gluten Free Ebola<br />Episode number: S18E02<br />IMDB rating: 7.8<br />Characteristic word: gluten","Episode name: The Cissy<br />Episode number: S18E03<br />IMDB rating: 8.6<br />Characteristic word: lorde","Episode name: Handicar<br />Episode number: S18E04<br />IMDB rating: 7.4<br />Characteristic word: handicar","Episode name: The Magic Bush<br />Episode number: S18E05<br />IMDB rating: 8<br />Characteristic word: drone","Episode name: Freemium Isn't Free<br />Episode number: S18E06<br />IMDB rating: 8.3<br />Characteristic word: freemium","Episode name: Grounded Vindaloop<br />Episode number: S18E07<br />IMDB rating: 9.1<br />Characteristic word: virtual","Episode name: Cock Magic<br />Episode number: S18E08<br />IMDB rating: 8.4<br />Characteristic word: mcnuggets","Episode name: #REHASH<br />Episode number: S18E09<br />IMDB rating: 7.5<br />Characteristic word: lorde","Episode name: #HappyHolograms<br />Episode number: S18E10<br />IMDB rating: 6.9<br />Characteristic word: trending","Episode name: Stunning and Brave<br />Episode number: S19E01<br />IMDB rating: 7.8<br />Characteristic word: pc","Episode name: Where My Country Gone?<br />Episode number: S19E02<br />IMDB rating: 8.3<br />Characteristic word: usa","Episode name: The City Part of Town<br />Episode number: S19E03<br />IMDB rating: 7.7<br />Characteristic word: sodosopa","Episode name: You're Not Yelping<br />Episode number: S19E04<br />IMDB rating: 8.1<br />Characteristic word: yelp","Episode name: Safe Space<br />Episode number: S19E05<br />IMDB rating: 8.5<br />Characteristic word: spaaaace","Episode name: Tweek x Craig<br />Episode number: S19E06<br />IMDB rating: 8<br />Characteristic word: tweek","Episode name: Naughty Ninjas<br />Episode number: S19E07<br />IMDB rating: 8.4<br />Characteristic word: ninjas","Episode name: Sponsored Content<br />Episode number: S19E08<br />IMDB rating: 9<br />Characteristic word: ad","Episode name: Truth and Advertising<br />Episode number: S19E09<br />IMDB rating: 8.2<br />Characteristic word: ads","Episode name: PC Principal Final Justice<br />Episode number: S19E10<br />IMDB rating: 8<br />Characteristic word: pc","Episode name: Member Berries<br />Episode number: S20E01<br />IMDB rating: 8<br />Characteristic word: member","Episode name: Skank Hunt<br />Episode number: S20E02<br />IMDB rating: 8.2<br />Characteristic word: twitter","Episode name: The Damned<br />Episode number: S20E03<br />IMDB rating: 8.2<br />Characteristic word: member","Episode name: Wieners Out<br />Episode number: S20E04<br />IMDB rating: 8<br />Characteristic word: trolls","Episode name: Douche and a Danish<br />Episode number: S20E05<br />IMDB rating: 7.4<br />Characteristic word: denmark","Episode name: Fort Collins<br />Episode number: S20E06<br />IMDB rating: 7.5<br />Characteristic word: member","Episode name: Oh, Jeez<br />Episode number: S20E07<br />IMDB rating: 7.1<br />Characteristic word: ambassador","Episode name: Members Only<br />Episode number: S20E08<br />IMDB rating: 7.5<br />Characteristic word: member","Episode name: Not Funny<br />Episode number: S20E09<br />IMDB rating: 7.5<br />Characteristic word: denmark","Episode name: The End of Serialization as We Know It<br />Episode number: S20E10<br />IMDB rating: 7<br />Characteristic word: elon","Episode name: White People Renovating Houses<br />Episode number: S21E01<br />IMDB rating: 6.6<br />Characteristic word: alexa","Episode name: Put It Down<br />Episode number: S21E02<br />IMDB rating: 7.9<br />Characteristic word: korea","Episode name: Holiday Special<br />Episode number: S21E03<br />IMDB rating: 7.7<br />Characteristic word: columbus","Episode name: Franchise Prequel<br />Episode number: S21E04<br />IMDB rating: 7.3<br />Characteristic word: zuckerberg","Episode name: Hummels & Heroin<br />Episode number: S21E05<br />IMDB rating: 7.4<br />Characteristic word: hummels","Episode name: Sons A Witches<br />Episode number: S21E06<br />IMDB rating: 7.3<br />Characteristic word: witch","Episode name: Doubling Down<br />Episode number: S21E07<br />IMDB rating: 7.4<br />Characteristic word: heidi","Episode name: Moss Piglets<br />Episode number: S21E08<br />IMDB rating: 7.2<br />Characteristic word: science","Episode name: SUPER HARD PCness<br />Episode number: S21E09<br />IMDB rating: 7.9<br />Characteristic word: m'alright","Episode name: Splatty Tomato<br />Episode number: S21E10<br />IMDB rating: 7.1<br />Characteristic word: whites"],"type":"scatter","mode":"markers","marker":{"autocolorscale":false,"color":"rgba(89,42,136,1)","opacity":0.6,"size":11.3385826771654,"symbol":"circle","line":{"width":1.88976377952756,"color":"rgba(89,42,136,1)"}},"hoveron":"points","showlegend":false,"xaxis":"x","yaxis":"y","hoverinfo":"text","frame":null}],"layout":{"margin":{"t":26.2283105022831,"r":7.30593607305936,"b":40.1826484018265,"l":31.4155251141553},"font":{"color":"rgba(0,0,0,1)","family":"","size":14.6118721461187},"xaxis":{"domain":[0,1],"automargin":true,"type":"linear","autorange":false,"range":[-13.3,301.3],"tickmode":"array","ticktext":["0","100","200","300"],"tickvals":[0,100,200,300],"categoryorder":"array","categoryarray":["0","100","200","300"],"nticks":null,"ticks":"","tickcolor":null,"ticklen":3.65296803652968,"tickwidth":0,"showticklabels":true,"tickfont":{"color":"rgba(77,77,77,1)","family":"","size":11.689497716895},"tickangle":-0,"showline":false,"linecolor":null,"linewidth":0,"showgrid":true,"gridcolor":"rgba(235,235,235,1)","gridwidth":0.66417600664176,"zeroline":false,"anchor":"y","title":"Episode number","titlefont":{"color":"rgba(0,0,0,1)","family":"","size":14.6118721461187},"hoverformat":".2f"},"yaxis":{"domain":[0,1],"automargin":true,"type":"linear","autorange":false,"range":[6.135,9.765],"tickmode":"array","ticktext":["7","8","9"],"tickvals":[7,8,9],"categoryorder":"array","categoryarray":["7","8","9"],"nticks":null,"ticks":"","tickcolor":null,"ticklen":3.65296803652968,"tickwidth":0,"showticklabels":true,"tickfont":{"color":"rgba(77,77,77,1)","family":"","size":11.689497716895},"tickangle":-0,"showline":false,"linecolor":null,"linewidth":0,"showgrid":true,"gridcolor":"rgba(235,235,235,1)","gridwidth":0.66417600664176,"zeroline":false,"anchor":"x","title":"IMDB rating","titlefont":{"color":"rgba(0,0,0,1)","family":"","size":14.6118721461187},"hoverformat":".2f"},"shapes":[{"type":"rect","fillcolor":null,"line":{"color":null,"width":0,"linetype":[]},"yref":"paper","xref":"paper","x0":0,"x1":1,"y0":0,"y1":1}],"showlegend":false,"legend":{"bgcolor":null,"bordercolor":null,"borderwidth":0,"font":{"color":"rgba(0,0,0,1)","family":"","size":11.689497716895}},"hovermode":"closest","barmode":"relative"},"config":{"doubleClick":"reset","modeBarButtonsToAdd":[{"name":"Collaborate","icon":{"width":1000,"ascent":500,"descent":-50,"path":"M487 375c7-10 9-23 5-36l-79-259c-3-12-11-23-22-31-11-8-22-12-35-12l-263 0c-15 0-29 5-43 15-13 10-23 23-28 37-5 13-5 25-1 37 0 0 0 3 1 7 1 5 1 8 1 11 0 2 0 4-1 6 0 3-1 5-1 6 1 2 2 4 3 6 1 2 2 4 4 6 2 3 4 5 5 7 5 7 9 16 13 26 4 10 7 19 9 26 0 2 0 5 0 9-1 4-1 6 0 8 0 2 2 5 4 8 3 3 5 5 5 7 4 6 8 15 12 26 4 11 7 19 7 26 1 1 0 4 0 9-1 4-1 7 0 8 1 2 3 5 6 8 4 4 6 6 6 7 4 5 8 13 13 24 4 11 7 20 7 28 1 1 0 4 0 7-1 3-1 6-1 7 0 2 1 4 3 6 1 1 3 4 5 6 2 3 3 5 5 6 1 2 3 5 4 9 2 3 3 7 5 10 1 3 2 6 4 10 2 4 4 7 6 9 2 3 4 5 7 7 3 2 7 3 11 3 3 0 8 0 13-1l0-1c7 2 12 2 14 2l218 0c14 0 25-5 32-16 8-10 10-23 6-37l-79-259c-7-22-13-37-20-43-7-7-19-10-37-10l-248 0c-5 0-9-2-11-5-2-3-2-7 0-12 4-13 18-20 41-20l264 0c5 0 10 2 16 5 5 3 8 6 10 11l85 282c2 5 2 10 2 17 7-3 13-7 17-13z m-304 0c-1-3-1-5 0-7 1-1 3-2 6-2l174 0c2 0 4 1 7 2 2 2 4 4 5 7l6 18c0 3 0 5-1 7-1 1-3 2-6 2l-173 0c-3 0-5-1-8-2-2-2-4-4-4-7z m-24-73c-1-3-1-5 0-7 2-2 3-2 6-2l174 0c2 0 5 0 7 2 3 2 4 4 5 7l6 18c1 2 0 5-1 6-1 2-3 3-5 3l-174 0c-3 0-5-1-7-3-3-1-4-4-5-6z"},"click":"function(gd) { \n        // is this being viewed in RStudio?\n        if (location.search == '?viewer_pane=1') {\n          alert('To learn about plotly for collaboration, visit:\\n https://cpsievert.github.io/plotly_book/plot-ly-for-collaboration.html');\n        } else {\n          window.open('https://cpsievert.github.io/plotly_book/plot-ly-for-collaboration.html', '_blank');\n        }\n      }"}],"cloud":false},"source":"A","attrs":{"3f28516522d0":{"text":{},"x":{},"y":{},"type":"scatter"}},"cur_data":"3f28516522d0","visdat":{"3f28516522d0":["function (y) ","x"]},"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.2,"selected":{"opacity":1},"debounce":0},"base_url":"https://plot.ly"},"evals":["config.modeBarButtonsToAdd.0.click"],"jsHooks":[]}</script><!--/html_preserve-->

## End of the series

This was the last article from the South Park text mining series. I showed you where to get all the South Park dialogs. You learned how to create a dataset of words from a dataset of spoken lines. This tidy data format helps you make powerful analyses more easily. You used **ggplot2** to create very informative plots, some of them even interactive because of the **plotly** package! You even used a statistical proportion test to compare characters to see who is the naughtiest one.

The last piece of knowledge you gained was how to describe document topics using the **tf–idf** analysis. It is a more sophisticated method than just using a raw word count of words that are not stop-words. Mainly because it can penalize words that are common across a set of documents.

You saw most of the code alongside the text. There are a few bits that I didn't include intentionally. To see all of the code, visit my [Github page](https://github.com/pdrhlik/vertabelo/tree/master/south-park-tf-idf) as usual.

If you need a bit more practice in R to do that, check out the [Data Visualization 101](https://academy.vertabelo.com/course/data-visualization-101) course on [Vertabelo academy](https://academy.vertabelo.com/). They will show you how to use the **ggplot2** package that I use to produce my plots.

Reach out to me if you would like any help with some of your analyses! Patrik out.
