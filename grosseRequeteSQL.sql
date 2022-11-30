SELECT post.ID,
PriceData.meta_value AS price,
SurfaceData.meta_value AS surface,
TypeData.meta_value AS type,
BedroomsCountData.meta_value AS bedrooms,
BathroomsCountData.meta_value AS bathrooms,
CoverImageData.meta_value AS coverImage

FROM tp.wp_posts AS post

INNER JOIN tp.wp_postmeta AS priceData
  ON post.ID = PriceData.post_id AND PriceData.meta_key = 'price'

INNER JOIN tp.wp_postmeta AS surfaceData
  ON post.ID = SurfaceData.post_id AND SurfaceData.meta_key = 'surface'

INNER JOIN tp.wp_postmeta AS typeData
  ON post.ID = TypeData.post_id AND TypeData.meta_key = 'type'

INNER JOIN tp.wp_postmeta AS BathroomsCountData
  ON post.ID = BathroomsCountData.post_id AND BathroomsCountData.meta_key = 'bedrooms_count'

INNER JOIN tp.wp_postmeta AS BedroomsCountData
  ON post.ID = BedroomsCountData.post_id AND BedroomsCountData.meta_key = 'bathrooms_count'

INNER JOIN tp.wp_postmeta AS CoverImageData
  ON post.ID = CoverImageData.post_id AND CoverImageData.meta_key = 'coverImage'

WHERE PriceData.meta_key = 'price' AND PriceData.meta_value > 100

GROUP BY price;



/**************************************************/





SELECT 
  post.ID AS ID,
  post.post_title,
  priceData.meta_value AS price,
  imageData.meta_value AS coverImage, 
  bedData.meta_value AS bedrooms_count, 
  bathData.meta_value AS bathrooms_count, 
  surfaceData.meta_value AS surface, 
  typeData.meta_value AS type

FROM tp.wp_posts AS post

INNER JOIN tp.wp_postmeta AS priceData
  ON post.ID = priceData.post_id AND priceData.meta_key = 'price'

INNER JOIN tp.wp_postmeta AS CoverImageData
  ON post.ID = imageData.post_id AND imageData.meta_key = 'coverImage'

INNER JOIN tp.wp_postmeta AS bedData
  ON post.ID = bedData.post_id AND bedData.meta_key = 'bedrooms_count'

INNER JOIN tp.wp_postmeta AS bathData
  ON post.ID = bathData.post_id AND bathData.meta_key = 'bathrooms_count'
  
INNER JOIN tp.wp_postmeta AS surfaceData
  ON post.ID = surfaceData.post_id AND surfaceData.meta_key = 'surface'

INNER JOIN tp.wp_postmeta AS typeData
  ON post.ID = typeData.post_id AND typeData.meta_key = 'type';



SELECT post.ID,
post.post_title,
PriceData.meta_value AS price,
SurfaceData.meta_value AS surface,
TypeData.meta_value AS type,
BedroomsCountData.meta_value AS bedrooms,
BathroomsCountData.meta_value AS bathrooms,
CoverImageData.meta_value AS coverImage

FROM tp.wp_posts AS post

INNER JOIN tp.wp_postmeta AS priceData
  ON post.ID = PriceData.post_id AND priceData.meta_key = 'price'

INNER JOIN tp.wp_postmeta AS surfaceData
  ON post.ID = SurfaceData.post_id AND surfaceData.meta_key = 'surface'

INNER JOIN tp.wp_postmeta AS typeData
  ON post.ID = TypeData.post_id AND typeData.meta_key = 'type'

INNER JOIN tp.wp_postmeta AS BathroomsCountData
  ON post.ID = BathroomsCountData.post_id AND BathroomsCountData.meta_key = 'bedrooms_count'

INNER JOIN tp.wp_postmeta AS BedroomsCountData
  ON post.ID = BedroomsCountData.post_id AND BedroomsCountData.meta_key = 'bathrooms_count'

INNER JOIN tp.wp_postmeta AS CoverImageData
  ON post.ID = CoverImageData.post_id AND CoverImageData.meta_key = 'coverImage';







/******************************************************************************************/




$whereClauses = [];

// Si l'utilisateur filtre sur cette donnée, alors on ajoute une condition SQL
if ( isset( $args['myFilter'] ) )
  $whereClauses[] = 'myFilter >= :myFilter';

// Si on a des clauses WHERE, alors on les ajoute à la requête
if ( count($whereClauses > 0) )
  $query .= " WHERE " . implode( ' AND ', $whereClauses );

// On récupère le PDOStatement
$stmt = $pdo->prepare( $query );

// On associe les placeholder aux valeurs de $args,
// on doit le faire ici, car nous n'avions pas accès au $stmt avant
if ( isset( $args['myFilter'] ) )
  $stmt->bindParam('myFilter', $args['myFilter'], PDO::PARAM_INT);

$stmt->execute();




$query = "
        SELECT post.ID,
          PriceData.meta_value AS price,
          SurfaceData.meta_value AS surface,
          TypeData.meta_value AS type,
          BedroomsCountData.meta_value AS bedrooms,
          BathroomsCountData.meta_value AS bathrooms,
          CoverImageData.meta_value AS coverImage
        
          FROM tp.wp_posts AS post
        
          INNER JOIN tp.wp_postmeta AS priceData
            ON post.ID = PriceData.post_id AND PriceData.meta_key = 'price'
        
          INNER JOIN tp.wp_postmeta AS surfaceData
            ON post.ID = SurfaceData.post_id AND SurfaceData.meta_key = 'surface'
        
          INNER JOIN tp.wp_postmeta AS typeData
            ON post.ID = TypeData.post_id AND TypeData.meta_key = 'type'
        
          INNER JOIN tp.wp_postmeta AS BathroomsCountData
            ON post.ID = BathroomsCountData.post_id AND BathroomsCountData.meta_key = 'bedrooms_count'
        
          INNER JOIN tp.wp_postmeta AS BedroomsCountData
            ON post.ID = BedroomsCountData.post_id AND BedroomsCountData.meta_key = 'bathrooms_count'
        
          INNER JOIN tp.wp_postmeta AS CoverImageData
            ON post.ID = CoverImageData.post_id AND CoverImageData.meta_key = 'coverImage'
      ";

      $whereClauses = [];
      if ( isset( $args['surface']['min'] ) )
          $whereClauses[] = '(SurfaceData.meta_key = \'surface\' AND SurfaceData.meta_value >= :surfaceMin)';

      if ( isset( $args['surface']['max'] ) )
          $whereClauses[] = '(SurfaceData.meta_key = \'surface\' AND SurfaceData.meta_value <= :surfaceMax)';

      if ( isset( $args['price']['min'] ) )
          $whereClauses[] = '(PriceData.meta_key = \'price\' AND PriceData.meta_value >= :priceMin)';

      if ( isset( $args['price']['max'] ) )
          $whereClauses[] = '(PriceData.meta_key = \'price\' AND PriceData.meta_value <= :priceMax)';

      if ( isset( $args['rooms'] ) )
          $whereClauses[] = '(BedroomsCountData.meta_key = \'bedrooms_count\' AND BedroomsCountData.meta_value >= :roomsBed)';

      if ( isset( $args['bathRooms'] ) )
          $whereClauses[] = '(BathroomsCountData.meta_key = \'bathrooms_count\' AND BathroomsCountData.meta_value >= :bathRooms)';

      if ( isset( $args['types'] ) )
          $whereClauses[] = '(TypeData.meta_key AND TypeData.meta_value = :types)';


      $whereClauses[] = 'WHERE post.post_author = :hotelID';

      /*Si on a des clauses WHERE, alors on les ajoute à la requête*/
      if ( $whereClauses != [] )
          $query .= " AND " . implode( ' AND ', $whereClauses );

      /*On récupère le PDOStatement*/
      $stmt = $this->getDB()->prepare( $query );

      /* On associe les placeholder aux valeurs de $args,*/
      /* on doit le faire ici, car nous n'avions pas accès au $stmt avant*/
      if ( isset( $args['surface']['min'] ) )
          $stmt->bindParam('surfaceMin', $args['surface']['min'], PDO::PARAM_INT);

      if ( isset( $args['surface']['max'] ) )
          $stmt->bindParam('surfaceMax', $args['surface']['max'], PDO::PARAM_INT);

      if ( isset( $args['price']['min'] ) )
          $stmt->bindParam('priceMin', $args['price']['min'], PDO::PARAM_INT);

      if ( isset( $args['price']['max'] ) )
          $stmt->bindParam('priceMax', $args['price']['max'], PDO::PARAM_INT);

      if ( isset( $args['rooms'] ) )
          $stmt->bindParam('BedroomsCountData', $args['rooms'], PDO::PARAM_INT);

      if ( isset( $args['bathRooms'] ) )
          $stmt->bindParam('BathroomsCountData', $args['bathRooms'], PDO::PARAM_INT);

      if ( isset( $args['types'] ) )
          $stmt->bindParam('TypeData', $args['types'], PDO::PARAM_INT);


      $stmt->execute();




WHERE TYPE IN ("Appartement", "Maison")

"IN('".implode("', ", $args["type"])."')"