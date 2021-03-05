Darkswarm.controller "CookiesBannerCtrl", ($scope, CookiesBannerService, $http, $window)->

  $scope.acceptCookies = ->
    $http.post('/api/legacy/cookies/consent')
    CookiesBannerService.close()
    CookiesBannerService.disable()
