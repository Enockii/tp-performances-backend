<?php

namespace App\Services\Reviews;

use App\Common\Cache;
use Psr\Cache\InvalidArgumentException;
use Symfony\Component\Cache\Adapter\FilesystemAdapter;
use Symfony\Component\Cache\Adapter\FilesystemTagAwareAdapter;
use Symfony\Contracts\Cache\ItemInterface;

class CachedApiReviewsService extends APIReviewsService
{
    /**
     * @param int $hotelID
     * @return array
     * @throws InvalidArgumentException
     */
    public function get ( int $hotelID ) : array {
        $cache = Cache::get()->getItem('review');
        $cache->set(parent::get($hotelID));
        $cache->expiresAfter(3600);
        return $cache->get();
        /*$cache = Cache::get();
        return $cache->get(
            'review',
            function ( ItemInterface $item) {
                $item->expiresAfter(3600);
                $item->tag('review');
                return $item->get();
            }
        );*/
    }
}