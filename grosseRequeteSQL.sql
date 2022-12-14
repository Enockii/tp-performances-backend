/**************************Question 4 - getCheapestroom()**************************/


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



  protected function getCheapestRoom ( HotelEntity $hotel, array $args = [] ) : RoomEntity
  {
      /* TIMER */
      $timer = Timers::getInstance();
      $timerId = $timer->startTimer('getCheapestRoom');
      /* /TIMER */

      /* Début de la requete avec le SELECT et tous les INNER JOIN
         pour rassembler toutes les données qui vont être nécessaires*/
      $query = "
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
      ";

      /* Suite de la requête : les WHERE, qui dépendent des critères de l'utilisateur donnés par $args[] */
      $whereClauses[] = "post.post_author = :hotelID AND post.post_type = 'room'";

      if (isset($args['surface']['min']))
          $whereClauses[] = 'SurfaceData.meta_value >= :surfaceMin';

      if (isset($args['surface']['max']))
          $whereClauses[] = 'SurfaceData.meta_value <= :surfaceMax';

      if (isset($args['price']['min']))
          $whereClauses[] = 'PriceData.meta_value >= :priceMin';

      if (isset($args['price']['max']))
          $whereClauses[] = 'PriceData.meta_value <= :priceMax';

      if (isset($args['rooms']))
          $whereClauses[] = 'BedroomsCountData.meta_value >= :roomsBed';

      if (isset($args['bathRooms']))
          $whereClauses[] = 'BathroomsCountData.meta_value >= :bathRooms';

      if (isset($args['types']) && !empty($args['types']))
          $whereClauses[] = "TypeData.meta_value IN('" . implode("', '", $args["types"]) . "')";


      /*On ajoute les clauses WHERE à la requête*/
      if ($whereClauses != [])
          $query .= " WHERE " . implode(' AND ', $whereClauses);

      $query .= " GROUP BY post.ID;";
      /*On récupère le PDOStatement*/
      $stmt = $this->getDB()->prepare($query);

      /*On récupère l'ID de l'hotel */
      $hotelID = $hotel->getId();
      $stmt->bindParam('hotelID', $hotelID, PDO::PARAM_INT);

      /*Bind des paramètres en fonction des clauses WHERE (donc des critères grâce à $args[])*/
      if (isset($args['surface']['min']))
          $stmt->bindParam('surfaceMin', $args['surface']['min'], PDO::PARAM_INT);

      if (isset($args['surface']['max']))
          $stmt->bindParam('surfaceMax', $args['surface']['max'], PDO::PARAM_INT);

      if (isset($args['price']['min']))
          $stmt->bindParam('priceMin', $args['price']['min'], PDO::PARAM_INT);

      if (isset($args['price']['max']))
          $stmt->bindParam('priceMax', $args['price']['max'], PDO::PARAM_INT);

      if (isset($args['rooms']))
          $stmt->bindParam('roomsBed', $args['rooms'], PDO::PARAM_INT);

      if (isset($args['bathRooms']))
          $stmt->bindParam('bathRooms', $args['bathRooms'], PDO::PARAM_INT);

      $stmt->execute();
      /*On regarde si la requête trouve bien une chambre correspond aux critères, sinon on génère une exception*/
      if(!($results = $stmt->fetch(PDO::FETCH_ASSOC)))
          throw new FilterException("Aucune chambre ne correspond aux critères.");

      /*Si la requête retourne un résultat : l'instancie*/
      $cheapestRoom = new RoomEntity();
      $cheapestRoom->setId($results['ID']);
      $cheapestRoom->setTitle($results['title']);
      $cheapestRoom->setPrice($results['price']);
      $cheapestRoom->setBathRoomsCount($results['bathrooms']);
      $cheapestRoom->setBedRoomsCount($results['bedrooms']);
      $cheapestRoom->setCoverImageUrl($results['coverImage']);
      $cheapestRoom->setSurface($results['surface']);
      $cheapestRoom->setType($results['types']);

      /* TIMER */
      $timer->endTimer('getCheapestRoom', $timerId);
      /* /TIMER*/

    return $cheapestRoom;
  }








/**************************Question 5 - getMetas()**************************/
$metaDatas = [
      'address' => [
        'address_1' => $this->getMeta( $hotel->getId(), 'address_1' ),
        'address_2' => $this->getMeta( $hotel->getId(), 'address_2' ),
        'address_city' => $this->getMeta( $hotel->getId(), 'address_city' ),
        'address_zip' => $this->getMeta( $hotel->getId(), 'address_zip' ),
        'address_country' => $this->getMeta( $hotel->getId(), 'address_country' ),
      ],
      'geo_lat' =>  $this->getMeta( $hotel->getId(), 'geo_lat' ),
      'geo_lng' =>  $this->getMeta( $hotel->getId(), 'geo_lng' ),
      'coverImage' =>  $this->getMeta( $hotel->getId(), 'coverImage' ),
      'phone' =>  $this->getMeta( $hotel->getId(), 'phone' ),
    ];

   SELECT address1Data.meta_value AS address_1,
          address2Data.meta_value AS address_2,
          addressCityData.meta_value AS address_city,
          addressZipData.meta_value AS address_zip,
          addressCountryData.meta_value AS address_country,
          CAST(geoLatData.meta_value AS float) AS geo_lat,
          CAST(geoLngData.meta_value AS float) AS geo_lng,
          phoneData.meta_value AS phone,
          emailData.meta_value AS email,
          coverImageData.meta_value AS coverImage

  FROM tp.wp_usermeta AS hotelData
  
  INNER JOIN tp.wp_usermeta AS address1Data
    ON hotelData.user_id = address1Data.user_id AND address1Data.meta_key = 'address_1'
        
  INNER JOIN tp.wp_usermeta AS address2Data
    ON hotelData.user_id = address2Data.user_id AND address2Data.meta_key = 'address_2'

  INNER JOIN tp.wp_usermeta AS addressCityData
    ON hotelData.user_id = addressCityData.user_id AND addressCityData.meta_key = 'address_city'

  INNER JOIN tp.wp_usermeta AS addressZipData
    ON hotelData.user_id = addressZipData.user_id AND addressZipData.meta_key = 'address_zip'

  INNER JOIN tp.wp_usermeta AS addressCountryData
    ON hotelData.user_id = addressCountryData.user_id AND addressCountryData.meta_key = 'address_country'

  INNER JOIN tp.wp_usermeta AS geoLatData
    ON hotelData.user_id = geoLatData.user_id AND geoLatData.meta_key = 'geo_lat'

  INNER JOIN tp.wp_usermeta AS geoLngData
    ON hotelData.user_id = geoLngData.user_id AND geoLngData.meta_key = 'geo_lng'

  INNER JOIN tp.wp_usermeta AS coverImageData
    ON hotelData.user_id = coverImageData.user_id AND coverImageData.meta_key = 'coverImage'

  INNER JOIN tp.wp_usermeta AS phoneData
    ON hotelData.user_id = phoneData.user_id AND phoneData.meta_key = 'phone'

  INNER JOIN tp.wp_usermeta AS emailData
    ON hotelData.user_id = emailData.user_id AND emailData.meta_key = 'email'


  WHERE hotelData.user_id = :hotelID

  GROUP BY hotelData.user_id;


protected function getMetas ( HotelEntity $hotel ) : array {
      /* TIMER */
      $timer = Timers::getInstance();
      $timerId = $timer->startTimer('getMetas');
      /* /TIMER */

      $stmt = $this->getDB()->prepare( "
        SELECT address1Data.meta_value AS address_1,
                  address2Data.meta_value AS address_2,
                  addressCityData.meta_value AS address_city,
                  addressZipData.meta_value AS address_zip,
                  addressCountryData.meta_value AS address_country,
                  CAST(geoLatData.meta_value AS float) AS geo_lat,
                  CAST(geoLngData.meta_value AS float) AS geo_lng,
                  phoneData.meta_value AS phone,
                  emailData.meta_value AS email,
                  coverImageData.meta_value AS coverImage
        
          FROM tp.wp_usermeta AS hotelData
          
          INNER JOIN tp.wp_usermeta AS address1Data
            ON hotelData.user_id = address1Data.user_id AND address1Data.meta_key = 'address_1'
                
          INNER JOIN tp.wp_usermeta AS address2Data
            ON hotelData.user_id = address2Data.user_id AND address2Data.meta_key = 'address_2'
        
          INNER JOIN tp.wp_usermeta AS addressCityData
            ON hotelData.user_id = addressCityData.user_id AND addressCityData.meta_key = 'address_city'
        
          INNER JOIN tp.wp_usermeta AS addressZipData
            ON hotelData.user_id = addressZipData.user_id AND addressZipData.meta_key = 'address_zip'
        
          INNER JOIN tp.wp_usermeta AS addressCountryData
            ON hotelData.user_id = addressCountryData.user_id AND addressCountryData.meta_key = 'address_country'
        
          INNER JOIN tp.wp_usermeta AS geoLatData
            ON hotelData.user_id = geoLatData.user_id AND geoLatData.meta_key = 'geo_lat'
        
          INNER JOIN tp.wp_usermeta AS geoLngData
            ON hotelData.user_id = geoLngData.user_id AND geoLngData.meta_key = 'geo_lng'
        
          INNER JOIN tp.wp_usermeta AS coverImageData
            ON hotelData.user_id = coverImageData.user_id AND coverImageData.meta_key = 'coverImage'
        
          INNER JOIN tp.wp_usermeta AS phoneData
            ON hotelData.user_id = phoneData.user_id AND phoneData.meta_key = 'phone'
        
          INNER JOIN tp.wp_usermeta AS emailData
            ON hotelData.user_id = emailData.user_id AND emailData.meta_key = 'email'
        
          WHERE hotelData.user_id = :hotelID
        
          GROUP BY hotelData.user_id;

        " );
      $stmt->execute([
          'hotelID' => $hotel->getId(),
      ]);

      $results = $stmt->fetch( PDO::FETCH_ASSOC );
      //dump($results);

    $metaDatas = [
      'address' => [
        'address_1' => $results['address_1'],
        'address_2' => $results['address_2'],
        'address_city' => $results['address_city'],
        'address_zip' =>  $results['address_zip'],
        'address_country' => $results['address_country'],
      ],
      'geo_lat' => $results['geo_lat'],
      'geo_lng' => $results['geo_lng'],
      'coverImage' => $results['coverImage'],
      'phone' => $results['phone'],
    ];

      /* TIMER */
      $timer->endTimer('getMetas', $timerId);
      /* /TIMER*/

    return $metaDatas;
  }





/************************** QUESTION 6 **********************************/

SELECT
   user.ID AS hotelId,
   user.display_name AS hotelName,
   postData.ID AS cheapestRoomId,
   postData.price AS price

FROM
    wp_users AS USER
    
    -- room
    INNER JOIN (
      SELECT
         post.ID,
         post.post_author,
         MIN(CAST(priceData.meta_value AS UNSIGNED)) AS price
      FROM
         tp.wp_posts AS post
            -- price
            INNER JOIN tp.wp_postmeta AS priceData ON post.ID = priceData.post_id
            AND priceData.meta_key = 'price'
      WHERE
         post.post_type = 'room'
      GROUP BY
         post.post_author
   ) AS postData ON user.ID = postData.post_author

WHERE
    -- On peut déjà filtrer vu que valeur est déjà castée en numérique
    postData.price < 100

LIMIT 3;





SELECT 
      hotelData.user_id AS hotelID,
      userData.display_name AS hotelName,
      address1Data.meta_value AS address_1,
      address2Data.meta_value AS address_2,
      addressCityData.meta_value AS address_city,
      addressZipData.meta_value AS address_zip,
      addressCountryData.meta_value AS address_country,
      CAST(geoLatData.meta_value AS float) AS geo_lat,
      CAST(geoLngData.meta_value AS float) AS geo_lng,
      phoneData.meta_value AS phone,
      emailData.meta_value AS email,
      coverImageData.meta_value AS coverImage
    
      FROM tp.wp_usermeta AS hotelData
      
      INNER JOIN tp.wp_usermeta AS address1Data
        ON hotelData.user_id = address1Data.user_id AND address1Data.meta_key = 'address_1'
            
      INNER JOIN tp.wp_usermeta AS address2Data
        ON hotelData.user_id = address2Data.user_id AND address2Data.meta_key = 'address_2'
    
      INNER JOIN tp.wp_usermeta AS addressCityData
        ON hotelData.user_id = addressCityData.user_id AND addressCityData.meta_key = 'address_city'
    
      INNER JOIN tp.wp_usermeta AS addressZipData
        ON hotelData.user_id = addressZipData.user_id AND addressZipData.meta_key = 'address_zip'
    
      INNER JOIN tp.wp_usermeta AS addressCountryData
        ON hotelData.user_id = addressCountryData.user_id AND addressCountryData.meta_key = 'address_country'
    
      INNER JOIN tp.wp_usermeta AS geoLatData
        ON hotelData.user_id = geoLatData.user_id AND geoLatData.meta_key = 'geo_lat'
    
      INNER JOIN tp.wp_usermeta AS geoLngData
        ON hotelData.user_id = geoLngData.user_id AND geoLngData.meta_key = 'geo_lng'
    
      INNER JOIN tp.wp_usermeta AS coverImageData
        ON hotelData.user_id = coverImageData.user_id AND coverImageData.meta_key = 'coverImage'
    
      INNER JOIN tp.wp_usermeta AS phoneData
        ON hotelData.user_id = phoneData.user_id AND phoneData.meta_key = 'phone'
    
      INNER JOIN tp.wp_usermeta AS emailData
        ON hotelData.user_id = emailData.user_id AND emailData.meta_key = 'email'


      INNER JOIN (
        SELECT
          user.ID,
          user.display_name
        FROM wp_users AS user
      ) AS userData ON hotelData.user_id = userData.ID

      INNER JOIN (
        SELECT 
          post_author,
          ROUND(AVG(CAST(wp_postmeta.meta_value AS UNSIGNED INTEGER))) AS rating, 
          COUNT(wp_postmeta.meta_value) AS ratingCount
        FROM wp_usermeta, wp_posts, wp_postmeta
        WHERE wp_usermeta.user_id = wp_posts.post_author AND wp_posts.ID = wp_postmeta.post_id AND wp_postmeta.meta_key = 'rating' AND wp_posts.post_type = 'review'
        GROUP BY wp_posts.post_author
      ) AS review ON hotelData.user_id = review.post_author
    
      GROUP BY hotelData.user_id;



/*******/

INNER JOIN (
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

              GROUP BY post.post_author

      ) AS hotelRoomData ON hotelData.user_id = hotelRoomData.ID

      GROUP BY hotelData.user_id;

/*******/









SELECT 
      hotel.ID AS hotelID,
      address1Data.meta_value AS address_1,
      address2Data.meta_value AS address_2,
      addressCityData.meta_value AS address_city,
      addressZipData.meta_value AS address_zip,
      addressCountryData.meta_value AS address_country,
      CAST(geoLatData.meta_value AS float) AS geo_lat,
      CAST(geoLngData.meta_value AS float) AS geo_lng,
      phoneData.meta_value AS phone,
      emailData.meta_value AS email,
      coverImageData.meta_value AS coverImage,
      hotelRoomData.title AS titleRoom
    
      FROM tp.wp_users AS hotel

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
    

      INNER JOIN (
        SELECT post.ID,
              post.post_author AS author,
              post.post_title AS title,
              MIN(CAST(PriceData.meta_value AS float)) AS price,
              CAST(SurfaceData.meta_value AS int) AS surface,
              TypeData.meta_value AS types,
              CAST(BedroomsCountData.meta_value AS int) AS bedrooms,
              CAST(BathroomsCountData.meta_value AS int) AS bathrooms,
              CoverImageData.meta_value AS coverImage
            
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

              WHERE post.post_type = 'room'

              GROUP BY post.post_author

      ) AS hotelRoomData ON hotel.ID = hotelRoomData.author

      GROUP BY hotel.ID;



  /** V3 avec ET cheapestRoom ET les 2 autres **/

  SELECT 
      hotel.ID AS hotelID,
      address1Data.meta_value AS address_1,
      address2Data.meta_value AS address_2,
      addressCityData.meta_value AS address_city,
      addressZipData.meta_value AS address_zip,
      addressCountryData.meta_value AS address_country,
      CAST(geoLatData.meta_value AS float) AS geo_lat,
      CAST(geoLngData.meta_value AS float) AS geo_lng,
      phoneData.meta_value AS phone,
      emailData.meta_value AS email,
      coverImageData.meta_value AS coverImage,
      hotelRoomData.title AS titleRoom,
      review.rating AS rating,
      review.ratingCount AS ratingCount
    
      FROM tp.wp_users AS hotel

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
    

      INNER JOIN (
        SELECT 
              post.post_author AS author,
              post.post_title AS title,
              MIN(CAST(PriceData.meta_value AS float)) AS price,
              CAST(SurfaceData.meta_value AS int) AS surface,
              TypeData.meta_value AS types,
              CAST(BedroomsCountData.meta_value AS int) AS bedrooms,
              CAST(BathroomsCountData.meta_value AS int) AS bathrooms,
              CoverImageData.meta_value AS coverImage
            
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

              WHERE post.post_type = 'room'

              GROUP BY post.post_author

      ) AS hotelRoomData ON hotel.ID = hotelRoomData.author



      INNER JOIN (
        SELECT 
          post_author AS author,
          ROUND(AVG(CAST(wp_postmeta.meta_value AS UNSIGNED INTEGER))) AS rating, 
          COUNT(wp_postmeta.meta_value) AS ratingCount
        FROM wp_usermeta, wp_posts, wp_postmeta
        WHERE wp_usermeta.user_id = wp_posts.post_author 
          AND wp_posts.ID = wp_postmeta.post_id 
          AND wp_postmeta.meta_key = 'rating' 
          AND wp_posts.post_type = 'review'
        GROUP BY wp_posts.post_author
      ) AS review ON hotel.ID = review.author

      GROUP BY hotel.ID;



http://localhost/?types%5B%5D=Maison&types%5B%5D=Appartement&price%5Bmin%5D=200&price%5Bmax%5D=230&surface%5Bmin%5D=130&surface%5Bmax%5D=150&rooms=5&bathRooms=5&lat=46.988708&lng=3.160778&search=Nevers&distance=30
http://localhost/?types%5B%5D=Maison&types%5B%5D=Appartement&price%5Bmin%5D=200&price%5Bmax%5D=230&surface%5Bmin%5D=130&surface%5Bmax%5D=150&rooms=5&bathRooms=5&lat=&lng=&search=Nevers&distance=30