Vous pouvez utiliser ce [GSheets](https://docs.google.com/spreadsheets/d/13Hw27U3CsoWGKJ-qDAunW9Kcmqe9ng8FROmZaLROU5c/copy?usp=sharing) pour suivre l'évolution de l'amélioration de vos performances au cours du TP 

## Question 2 : Utilisation Server Timing API

**Temps de chargement initial de la page** : TEMPS

**Choix des méthodes à analyser** :

- `getMeta` : 4.21s
- `getMetas` : 4.43s
- `getReviews` : 8.96s
- `getCheapestRoom` : 16.12s



## Question 3 : Réduction du nombre de connexions PDO

**Temps de chargement de la page** : 30.45s

**Temps consommé par `getDB()`** 

- **Avant** 1.38s (2201)

- **Après** 6.61<u>m</u>s


## Question 4 : Délégation des opérations de filtrage à la base de données

**Temps de chargement globaux** 

- **Avant** 29.14s

- **Après** 20.73s


#### Amélioration de la méthode `getMeta()` et donc de la méthode `getMetas()` :

- **Avant** 3.03s (et donc 3.16s)

```sql
SELECT * FROM wp_usermeta;
```

- **Après** 1.44s (et donc 1.45s)

```sql
SELECT meta_value FROM wp_usermeta WHERE user_id = :user_id AND meta_key = :key;
```



#### Amélioration de la méthode `getReviews()` :

- **Avant** 8.35s

```sql
SELECT * FROM wp_posts, wp_postmeta WHERE wp_posts.post_author = :hotelId AND wp_posts.ID = wp_postmeta.post_id AND meta_key = 'rating' AND post_type = 'review';
```

- **Après** 6.33s

```sql
SELECT ROUND(AVG(CAST(meta_value AS UNSIGNED INTEGER))) AS rating, COUNT(meta_value) AS ratingCount FROM wp_posts, wp_postmeta WHERE wp_posts.post_author = :hotelId AND wp_posts.ID = wp_postmeta.post_id AND meta_key = 'rating' AND post_type = 'review';
```



#### Amélioration de la méthode `getCheapestRoom` :

- **Avant** 16.59s (331ms pour la recherche du contrôle de non regression)

```sql
SELECT * FROM wp_posts WHERE post_author = :hotelId AND post_type = 'room';
```

- **Après** 11.95s (277ms pour la recherche du contrôle de non regression)

```sql
SELECT post.ID,
       post.post_title AS title,
       MIN(CAST(PriceData.meta_value AS float)) AS price,
       CAST(SurfaceData.meta_value AS int) AS surface,
       TypeData.meta_value AS types,
       CAST(BedroomsCountData.meta_value AS int) AS bedrooms,
       CAST(BathroomsCountData.meta_value AS int) AS bathrooms,
       CoverImageData.meta_value AS coverImage

FROM tp.wp_posts AS post

      INNER JOIN tp.wp_postmeta AS SurfaceData
                 ON post.ID = SurfaceData.post_id
                  AND SurfaceData.meta_key = 'surface'

      INNER JOIN tp.wp_postmeta AS PriceData
                 ON post.ID = PriceData.post_id
                  AND PriceData.meta_key = 'price'

      INNER JOIN tp.wp_postmeta AS TypeData
                 ON post.ID = TypeData.post_id
                  AND TypeData.meta_key = 'type'

      INNER JOIN tp.wp_postmeta AS BedroomsCountData
                 ON post.ID = BedroomsCountData.post_id
                  AND BedroomsCountData.meta_key = 'bedrooms_count'

      INNER JOIN tp.wp_postmeta AS BathroomsCountData
                 ON post.ID = BathroomsCountData.post_id
                  AND BathroomsCountData.meta_key = 'bathrooms_count'

      INNER JOIN tp.wp_postmeta AS CoverImageData
                 ON post.ID = CoverImageData.post_id AND CoverImageData.meta_key = 'coverImage'

WHERE post.post_author = :hotelID AND post.post_type = 'room'
  AND SurfaceData.meta_value >= :surfaceMin
  AND SurfaceData.meta_value <= :surfaceMax
  AND PriceData.meta_value >= :priceMin
  AND PriceData.meta_value <= :priceMax
  AND BedroomsCountData.meta_value >= :roomsBed
  AND BathroomsCountData.meta_value >= :bathRooms
  AND TypeData.meta_value IN('Maison', 'Appartement')
GROUP BY post.ID;
```


## Question 5 : Réduction du nombre de requêtes SQL pour `getMetas`

|                              | **Avant** | **Après** |
|------------------------------|-----------|-----------|
| Nombre d'appels de `getDB()` | 2201      | 601       |
| Temps de `getMetas()`        | 1.68s     | 1.52s     |

## Question 6 : Création d'un service basé sur une seule requête SQL

|                              | **Avant** | **Après** |
|------------------------------|-----------|-----------|
| Nombre d'appels de `getDB()` | 601       | 1         |
| Temps de chargement global   | 23.60s    | 7.64s     |

**Requête SQL**

```SQL
SELECT
    hotel.ID                                AS hotelID,
    hotel.display_name                      AS hotelName,
    address1Data.meta_value                 AS hotelAddress_1,
    address2Data.meta_value                 AS hotelAddress_2,
    addressCityData.meta_value              AS hotelAddress_city,
    addressZipData.meta_value               AS hotelAddress_zip,
    addressCountryData.meta_value           AS hotelAddress_country,
    CAST(geoLatData.meta_value AS float)    AS hotelGeo_lat,
    CAST(geoLngData.meta_value AS float)    AS hotelGeo_lng,
    phoneData.meta_value                    AS hotelPhone,
    emailData.meta_value                    AS hotelEmail,
    coverImageData.meta_value               AS hotelCoverImage,
    review.rating                           AS hotelRating,
    review.ratingCount                      AS hotelRatingCount,
    hotelRoomData.author                    AS cheapestRHotel,
    hotelRoomData.title                     AS cheapestRTitle,
    hotelRoomData.price                     AS cheapestRPrice,
    hotelRoomData.surface                   AS cheapestRSurface,
    hotelRoomData.types                     AS cheapestRTypes,
    hotelRoomData.bedrooms                  AS cheapestRBedrooms,
    hotelRoomData.bathrooms                 AS cheapestRBathrooms,
    hotelRoomData.coverImage                AS cheapestRCoverImage

FROM tp.wp_users AS hotel

    
/*** Données de l'hotel ***/
 INNER JOIN tp.wp_usermeta AS address1Data
            ON hotel.ID = address1Data.user_id AND address1Data.meta_key = 'address_1'

 INNER JOIN tp.wp_usermeta AS address2Data
            ON hotel.ID = address2Data.user_id AND address2Data.meta_key = 'address_2'

 INNER JOIN tp.wp_usermeta AS addressCityData
            ON hotel.ID = addressCityData.user_id AND addressCityData.meta_key = 'address_city'

 INNER JOIN tp.wp_usermeta AS addressZipData
            ON hotel.ID = addressZipData.user_id AND addressZipData.meta_key = 'address_zip'

 INNER JOIN tp.wp_usermeta AS addressCountryData
            ON hotel.ID = addressCountryData.user_id AND addressCountryData.meta_key = 'address_country'

 INNER JOIN tp.wp_usermeta AS geoLatData
            ON hotel.ID = geoLatData.user_id AND geoLatData.meta_key = 'geo_lat'

 INNER JOIN tp.wp_usermeta AS geoLngData
            ON hotel.ID = geoLngData.user_id AND geoLngData.meta_key = 'geo_lng'

 INNER JOIN tp.wp_usermeta AS coverImageData
            ON hotel.ID = coverImageData.user_id AND coverImageData.meta_key = 'coverImage'

 INNER JOIN tp.wp_usermeta AS phoneData
            ON hotel.ID = phoneData.user_id AND phoneData.meta_key = 'phone'

 INNER JOIN tp.wp_usermeta AS emailData
            ON hotel.ID = emailData.user_id AND emailData.meta_key = 'email'

     
/*** Données de la chambre la moins chere de l'hôtel ***/
 INNER JOIN (
    SELECT
        post.post_author                             AS author,
        post.post_title                              AS title,
        CAST(PriceData.meta_value AS float)          AS price,
        CAST(SurfaceData.meta_value AS int)          AS surface,
        TypeData.meta_value                          AS types,
        CAST(BedroomsCountData.meta_value AS int)    AS bedrooms,
        CAST(BathroomsCountData.meta_value AS int)   AS bathrooms,
        CoverImageData.meta_value                    AS coverImage

    FROM tp.wp_posts AS post

    INNER JOIN tp.wp_postmeta AS SurfaceData
            ON post.ID = SurfaceData.post_id AND SurfaceData.meta_key = 'surface'
    
    INNER JOIN tp.wp_postmeta AS PriceData
            ON post.ID = PriceData.post_id AND PriceData.meta_key = 'price'
    
    INNER JOIN tp.wp_postmeta AS TypeData
            ON post.ID = TypeData.post_id AND TypeData.meta_key = 'type'
    
    INNER JOIN tp.wp_postmeta AS BedroomsCountData
            ON post.ID = BedroomsCountData.post_id AND BedroomsCountData.meta_key = 'bedrooms_count'
    
    INNER JOIN tp.wp_postmeta AS BathroomsCountData
            ON post.ID = BathroomsCountData.post_id AND BathroomsCountData.meta_key = 'bathrooms_count'
    
    INNER JOIN tp.wp_postmeta AS CoverImageData
            ON post.ID = CoverImageData.post_id AND CoverImageData.meta_key = 'coverImage'

 ) AS hotelRoomData ON hotel.ID = hotelRoomData.author


/*** Review de l'hôtel ***/
 INNER JOIN (
    SELECT
        post_author                                                   AS author,
        ROUND(AVG(CAST(wp_postmeta.meta_value AS UNSIGNED INTEGER)))  AS rating,
        COUNT(wp_postmeta.meta_value)                                 AS ratingCount

    FROM wp_usermeta, wp_posts, wp_postmeta

    WHERE wp_usermeta.user_id = wp_posts.post_author
      AND wp_posts.ID = wp_postmeta.post_id
      AND wp_postmeta.meta_key = 'rating'
      AND wp_posts.post_type = 'review'

    GROUP BY wp_posts.post_author

 ) AS review ON hotel.ID = review.author


/*** Conditions de recherche demandées par l'utilisateur ***/
WHERE 
  (111.111 * DEGREES(ACOS(LEAST(1.0, COS(RADIANS( CAST(geoLatData.meta_value AS float)))
      * COS(RADIANS( :lat ))
      * COS(RADIANS( CAST(geoLngData.meta_value AS float) - :lng ))
      + SIN(RADIANS( CAST(geoLatData.meta_value AS float)))
      * SIN(RADIANS( :lat )))))
  ) <= :distance 
  AND surface >= :surfaceMin 
  AND surface <= :surfaceMax 
  AND price >= :priceMin 
  AND price <= :priceMax 
  AND bedrooms >= :roomsBed 
  AND bathrooms >= :bathRooms 
  AND types IN('Maison', 'Appartement') 


GROUP BY hotel.ID; 

```

## Question 7 : ajout d'index SQL

**Index ajoutés**

- `wp_usermeta` : `user_id`
- `wp_postmeta` : `post_id`
- `wp_posts` : `ID`

**Requête SQL d'ajout des index** 

```sql
ALTER TABLE `wp_usermeta` ADD INDEX(`user_id`);
ALTER TABLE `wp_postmeta` ADD INDEX(`post_id`);
ALTER TABLE `wp_posts` ADD INDEX(`post_author`);
```

| Temps de chargement de la page   | Sans filtre   | Avec filtres   |
|----------------------------------|---------------|----------------|
| `UnoptimizedService`  (avant)    | 22.43s        | 12.39s         |
| `UnoptimizedService`  (après)    | 657ms         | 620ms          |
| -------------------------------- | ------------- | -------------- |
| `OneRequestService`   (avant)    | 7.58s         | 3.71s          |
| `OneRequestService`   (après)    | 2.07s         | 1.89s          |
[Filtres à utiliser pour mesurer le temps de chargement](http://localhost/?types%5B%5D=Maison&types%5B%5D=Appartement&price%5Bmin%5D=200&price%5Bmax%5D=230&surface%5Bmin%5D=130&surface%5Bmax%5D=150&rooms=5&bathRooms=5&lat=46.988708&lng=3.160778&search=Nevers&distance=30)




## Question 8 : restructuration des tables

**Temps de chargement de la page**

| Temps de chargement de la page | Sans filtre | Avec filtres |
|--------------------------------|-------------|--------------|
| `OneRequestService`            | TEMPS       | TEMPS        |
| `ReworkedHotelService`         | TEMPS       | TEMPS        |

[Filtres à utiliser pour mesurer le temps de chargement](http://localhost/?types%5B%5D=Maison&types%5B%5D=Appartement&price%5Bmin%5D=200&price%5Bmax%5D=230&surface%5Bmin%5D=130&surface%5Bmax%5D=150&rooms=5&bathRooms=5&lat=46.988708&lng=3.160778&search=Nevers&distance=30)

### Table `hotels` (200 lignes)

```SQL
-- REQ SQL CREATION TABLE
```

```SQL
-- REQ SQL INSERTION DONNÉES DANS LA TABLE
```

### Table `rooms` (1 200 lignes)

```SQL
-- REQ SQL CREATION TABLE
```

```SQL
-- REQ SQL INSERTION DONNÉES DANS LA TABLE
```

### Table `reviews` (19 700 lignes)

```SQL
-- REQ SQL CREATION TABLE
```

```SQL
-- REQ SQL INSERTION DONNÉES DANS LA TABLE
```


## Question 13 : Implémentation d'un cache Redis

**Temps de chargement de la page**

| Sans Cache | Avec Cache |
|------------|------------|
| TEMPS      | TEMPS      |
[URL pour ignorer le cache sur localhost](http://localhost?skip_cache)

## Question 14 : Compression GZIP

**Comparaison des poids de fichier avec et sans compression GZIP**

|                       | Sans  | Avec  |
|-----------------------|-------|-------|
| Total des fichiers JS | POIDS | POIDS |
| `lodash.js`           | POIDS | POIDS |

## Question 15 : Cache HTTP fichiers statiques

**Poids transféré de la page**

- **Avant** : POIDS
- **Après** : POIDS

## Question 17 : Cache NGINX

**Temps de chargement cache FastCGI**

- **Avant** : TEMPS
- **Après** : TEMPS

#### Que se passe-t-il si on actualise la page après avoir coupé la base de données ?

REPONSE

#### Pourquoi ?

REPONSE
