<?php

namespace App\Services\Reviews;

use App\Common\Timers;
use App\Entities\HotelEntity;
use App\Entities\RoomEntity;
use Exception;

class APIReviewsService
{
    private string $api_url = "http://cheap-trusted-reviews.fake/?hotel_id=";

    /**
     * @param int $hotelID
     * @return array
     */
    public function get ( int $hotelID ) : array {
        $new_api_url = $this->api_url . $hotelID;
        return json_decode(file_get_contents($new_api_url), true);
    }

}