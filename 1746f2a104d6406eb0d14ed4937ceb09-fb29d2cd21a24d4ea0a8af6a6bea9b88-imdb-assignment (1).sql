use imdb;

SET SQL_SAFE_UPDATES = 0;
show tables;

-- Segment 1: Database - Tables, Columns, Relationships
-- -        What are the different tables in the database and how are they connected to each other in the database?

  -- Find the total number of rows in each table of the schema.
  -- method 1
 select count(*) as total_rows from director_mapping;
 select count(*) as total_rows from genre;
 select count(*) as total_rows from movies;
 select count(*) as total_rows from ratings;
 select count(*) as total_rows from role_mapping;
 
 -- method 2
 select table_name,table_rows from information_schema.tables where table_schema = 'imdb';
 
 --  Identify which columns in the movie table have null values.
 select column_name from information_schema.columns 
 where table_name = 'movies'
 and table_schema = 'imdb'
 and is_nullable = 'yes';
 
-- Segment 2: Movie Release Trends
-- -Determine the total number of movies released each year and analyse the month-wise trend.
 
select month(date_published) as release_month,year,count(id) 
from movies 
group by year,month(date_published)
order by year,month(date_published);

-- Calculate the number of movies produced in the USA or India in the year 2019.
select count(id) from movies 
where (country like '%USA%' 
or country like '%India%')
and year = 2019;

-- Segment 3: Production Statistics and Genre Analysis
-- -Retrieve the unique list of genres present in the dataset.
select distinct genre from genre
order by genre;

-- Identify the genre with the highest number of movies produced overall.
select * from genre;
select genre,count(movie_id) from genre
group by genre 
order by count(movie_id) desc
limit 1;

-- Determine the count of movies that belong to only one genre.
select count(movie_id) from 
(select movie_id, count(genre) from genre group by movie_id having count(genre) = 1)t;

-- Calculate the average duration of movies in each genre.
select g.genre,avg(m.duration) as avg_duration
from movies m join genre g
on m.id = g.movie_id
group by g.genre;

-- Find the rank of the 'thriller' genre among all genres in terms of the number of movies produced.
-- using cte
with thriller_cte as
(select genre,count(movie_id),
rank() over(order by count(movie_id) desc) as rk from genre group by genre)

select genre, rk from thriller_cte 
where genre = 'Thriller';

-- using subquery
select genre,rk from 
(select genre,count(movie_id),
rank() over(order by count(movie_id) desc) as rk from genre group by genre)t
where genre = 'Thriller';

-- Segment 4: Ratings Analysis and Crew Members
-- -	Retrieve the minimum and maximum values in each column of the ratings table (except movie_id).

select * from ratings;
select min(avg_rating) as min_avg_rating,
max(avg_rating) as max_avg_rating,
min(total_votes) as min_votes,
max(total_votes) as max_votes,
min(median_rating) as min_med_rating,
max(median_rating) as max_med_rating
from ratings;

-- Identify the top 10 movies based on average rating.
select m.title,r.avg_rating from movies m left join ratings r
on m.id = r.movie_id
order by avg_rating desc
limit 10;

-- Summarise the ratings table based on movie counts by median ratings.
select median_rating, count(movie_id) from ratings 
group by median_rating
order by count(movie_id) desc;

-- Identify the production house that has produced the most number of hit movies (average rating > 8).
with hitmovies_cte as 
(select m.production_company,count(r.movie_id) as hit_movies 
from ratings r right join movies m
on m.id = r.movie_id 
where r.avg_rating > 8 
group by m.production_company)

select production_company,hit_movies 
from hitmovies_cte
order by hit_movies desc
limit 1;

-- -	Determine the number of movies released in each genre during March 2017 in the USA with more than 1,000 votes
with movie_cte as (
select m.id, g.genre, month(m.date_published) as month_of_publishing,m.year as year_of_publishing,m.country,r.total_votes from movies m 
join genre g on m.id = g.movie_id
join ratings r on g.movie_id = r.movie_id
)

select genre,count(id) from movie_cte
where month_of_publishing = 3 
and year_of_publishing = 2017
and country like '%USA%' 
and total_votes > 1000
group by genre
order by count(id) desc;

-- Retrieve movies of each genre starting with the word 'The' and having an average rating > 8.
with genre_cte as (
select m.title, r.avg_rating, g.genre from movies m
join ratings r on m.id = r.movie_id
join genre g on r.movie_id = g.movie_id
where title like 'The%' and avg_rating > 8)

select title,group_concat(genre) 
from genre_cte
group by title;


-- Segment 5: Crew Analysis
-- -	Identify the columns in the names table that have null values.
 
 select column_name from information_schema.columns 
 where table_name = 'names'
 and table_schema = 'imdb'
 and is_nullable = 'yes';
 
 -- Determine the top three directors in the top three genres with movies having an average rating > 8.
 -- hit movies (avg_rating > 8) in top 3 genres directed by top 3 directors

with top3_genre as(select genre,count(movie_id) as num_movies
from genre 
where movie_id in(select movie_id from ratings where avg_rating > 8)
group by genre
order by num_movies desc
limit 3),

top3_director_ids as(select name_id,count(movie_id)from director_mapping
where movie_id in(select movie_id from genre where genre in(select genre from top3_genre))
group by name_id
order by count(movie_id) desc
limit 3)

select n.name from top3_director_ids id
join names n on id.name_id = n.id;


-- -	Find the top two actors whose movies have a median rating >= 8.

with actor_cte as (
select n.id, count(r.movie_id) as num_movies from ratings r 
join role_mapping rm
on r.movie_id = rm.movie_id
join names n
on rm.name_id = n.id
where rm.category = 'actor' and r.median_rating >= 8
group by n.id
order by num_movies desc
limit 2)

select n.name from actor_cte ac
join names n 
on ac.id = n.id;

-- Identify the top three production houses based on the number of votes received by their movies.

with production_cte as (select m.production_company, sum(r.total_votes) as tot_vot
from movies m join ratings r
on m.id = r.movie_id
group by production_company)

select production_company from production_cte order by tot_vot desc limit 3;

-- Rank actors based on their average ratings in Indian movies released in India.
with actor_cte as (select m.id, r.avg_rating, rm.name_id  from movies m
join ratings r
on m.id = r.movie_id
join role_mapping rm
on r.movie_id = rm.movie_id
where rm.category = 'actor' 
and country like '%India%')

select n.name,dense_rank() over(order by avg_rating desc) as rk from names n join actor_cte ac
on n.id = ac.name_id;

--  Identify the top five actresses in Hindi movies released in India based on their average ratings.

with actress_cte as (select m.id, r.avg_rating, rm.name_id  from movies m
join ratings r
on m.id = r.movie_id
join role_mapping rm
on r.movie_id = rm.movie_id
where rm.category = 'actress' 
and country like '%India%'
and languages like '%Hindi%')

select name from
(select n.name,
rank() over(order by avg_rating desc) as rk 
from names n join actress_cte ac
on n.id = ac.name_id)t
where rk <= 5;


-- Segment 6: Broader Understanding of Data
-- -	Classify thriller movies based on average ratings into different categories.
-- Rating > 8: Superhit
-- Rating between 7 and 8: Hit
-- Rating between 5 and 7: One-time-watch
-- Rating < 5: Flop
with category_cte as
(select g.movie_id, r.avg_rating ,
case
when r.avg_rating > 8 then 'Superhit'
when r.avg_rating between 7 and 8 then 'Hit'
when r.avg_rating between 5 and 7 then 'One-time-watch'
when r.avg_rating < 5 then 'flop'
end as category
from genre g join ratings r
on g.movie_id = r.movie_id where genre = 'Thriller'
order by avg_rating desc)

select m.title, cc.category from movies m join category_cte cc
on m.id = cc.movie_id order by cc.avg_rating desc;

-- analyse the genre-wise running total and moving average of the average movie duration.

with running_cte as 
(select g.genre,round(avg(m.duration),2) as avg_duration from movies m join genre g
on m.id = g.movie_id group by g.genre order by genre)

select genre, avg_duration, 
sum(avg_duration) over(order by genre rows between unbounded preceding and current row) as running_total,
round(avg(avg_duration) over(order by genre rows between unbounded preceding and current row),2) as moving_avg
from running_cte;

-- -	Identify the five highest-grossing movies of each year that belong to the top three genres.
select * from movies;

with top3_genres as (select genre,count(movie_id) as num_movies
from genre group by genre order by num_movies desc limit 3)

select year,id,gross_income, g.genre, rk from
(select year, id, replace(worlwide_gross_income,'$ ','') as gross_income, 
dense_rank() over(partition by year order by  replace(worlwide_gross_income,'$ ','') desc) as rk
from movies)t join genre g on t.id = g.movie_id where rk<=5 and genre in (select genre from top3_genres)
order by year,rk;

-- -Determine the top two production houses that have produced the highest number of hits among multilingual movies.

select languages, locate(',',languages) from movies;
select production_company,count(id) from movies where
id in (select movie_id from ratings where avg_rating > 8)
and locate(',',languages) > 0 
and production_company is not null
group by production_company
order by count(id) desc
limit 2;

-- Identify the top three actresses based on the number of Super Hit movies (average rating > 8) in the drama genre.

with actress_cte as
(select rm.name_id, count(r.movie_id) as num_movies ,
sum(avg_rating * total_votes)/sum(total_votes) as actress_avg_rating 
from role_mapping rm join ratings r
on rm.movie_id = r.movie_id
join genre g on
r.movie_id = g.movie_id
where rm.category = 'actress'
and g.genre = 'Drama'
group by rm.name_id
having sum(r.avg_rating*r.total_votes)/sum(total_votes) > 8
order by num_movies desc
limit 3)

select n.name,dense_rank() over(order by actress_avg_rating desc) as rk from actress_cte ac join names n on
ac.name_id = n.id;

-- -Retrieve details for the top nine directors based on the number of movies, including average inter-movie duration, ratings, and more.

with top_directors as
(Select name_id as director_id,count(movie_id) as movie_count
from director_mapping group by name_id
order by movie_count desc
limit 9),

movies_summary as
(select b.name_id as director_id,a.*,avg_rating,total_votes
from movies a join director_mapping b
on a.id = b.movie_id
left join ratings c
on a.id = c.movie_id
where b.name_id in (select director_id from top_directors)),

final as
(select *, lead(date_published) over (partition by director_id order by date_published) as nxt_movie_date,
datediff(lead(date_published) over (partition by director_id order by date_published),date_published) as days_gap
from movies_summary)

select director_id,b.name as director_name,
count(a.id) as movie_count,
round(avg(days_gap),0) as avg_inter_movie_duration,
round(sum(avg_rating*total_votes)/sum(total_votes),2) as avg_movie_ratings,
sum(Total_votes) as total_votes,
min(avg_rating) as min_rating,
max(avg_rating) as max_rating,
sum(duration) as total_duration
from final a
join names b
on a.director_id = b.id
group by director_id,name
order by avg_movie_ratings desc;

select id,title,duration,lag(duration,1) over(order by date_published ),duration-lag(duration,1) over(order by date_published ) from movies;

-- Segment 7: Recommendations

-- Based on the analysis, provide recommendations for the types of content Bolly movies should focus on producing.
-- genre, actors, actress, directors, month during the which they want to make the release 


-- Insights drawn from the IMDB analysis
-- 1) Drama,Comedy and Thriller are the top 3 genres where highest number of movies are produced.
-- 2) Drama genre has the greatest average movie duration.
-- 3)Actors : Mamotty and Mohanlal are the top 2 actors based on their average movie ratings.
-- 4)Production company: Marvel Studios, Twentieth Century fox and Warner Bros are the top 3 production companies on the basis of number of votes received for their movie.
-- 5)Actress: In Indian Hindi movies, Mahie gill, Pranati Raikash, Leera Kaljai are the top 3 actress.