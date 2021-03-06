CREATE TABLE director (
	id SERIAL PRIMARY KEY,
	name VARCHAR(50) NOT NULL,
	birth_year INTEGER NOT NULL
);

CREATE TABLE movie (
	id SERIAL PRIMARY KEY,
	name VARCHAR(50) NOT NULL,
	year INTEGER NOT NULL,
	director_id INTEGER NOT NULL,
	CONSTRAINT movie_director_id FOREIGN KEY (director_id)
	REFERENCES director (id) MATCH SIMPLE
	ON UPDATE RESTRICT ON DELETE RESTRICT
);

INSERT INTO director (id, name, birth_year) VALUES (1, 'Alfred Hitchcock', 1899);
INSERT INTO director (id, name, birth_year) VALUES (2, 'Steven Spielberg', 1946);
INSERT INTO director (id, name, birth_year) VALUES (3, 'Woody Allen', 1935);
INSERT INTO director (id, name, birth_year) VALUES (4, 'Quentin Tarantino', 1963);
INSERT INTO director (id, name, birth_year) VALUES (5, 'Pedro Almodóvar', 1949);

INSERT INTO movie (id, name, year, director_id) VALUES (1, 'Psycho', 1960, 1);
INSERT INTO movie (id, name, year, director_id) VALUES (2, 'Saving Private Ryan', 1998, 2);
INSERT INTO movie (id, name, year, director_id) VALUES (3, 'Schindler''s List', 1993, 2);
INSERT INTO movie (id, name, year, director_id) VALUES (4, 'Midnight in Paris', 2011, 3);
INSERT INTO movie (id, name, year, director_id) VALUES (5, 'Sweet and Lowdown', 1993, 3);
INSERT INTO movie (id, name, year, director_id) VALUES (6, 'Pulp fiction', 1994, 4);
INSERT INTO movie (id, name, year, director_id) VALUES (7, 'Talk to her', 2002, 5);
INSERT INTO movie (id, name, year, director_id) VALUES (8, 'The skin I live in', 2011, 5);
