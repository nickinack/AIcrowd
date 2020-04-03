function startVideoPlayers(){
  var $videos = $('video');
  if ($videos.is(':in-viewport')) {
    $videos.each(function(){
      console.log('starting video: ' + this);
      var playPromise = this.play();
    });
  }
}

function pauseAndPlay(){
  var scrollTimeout = null;
  $(window).scroll(function(){
    if (scrollTimeout) {
      clearTimeout(scrollTimeout);
    }
    scrollTimeout = setTimeout(function() {
      startVideoPlayers();
    }, 2000);
  });
}


function copyLink() {
  var hiddenInput = document.getElementById("shortUrl");
  hiddenInput.style.display = 'block';
  hiddenInput.select();
  document.execCommand("copy");
  hiddenInput.style.display = 'none';
  var copybtn = document.getElementById("copyurlbutton");
  copybtn.style.text = '#FFFFFF';
  copybtn.style.backgroundColor = '#44B174';
  copybtn.classList.remove("btn-secondary");
  copybtn.classList.add("btn-primary");
  copybtn.innerHTML = "Copied!";
  return false;
}


Paloma.controller('Leaderboards', {
  index: function(){
    pauseAndPlay();
  },
  show: function(){
    pauseAndPlay();
  }
});

$(document).ready(function(){
  $('.social-share').click(function(){
    var socialSelector;
    if(this.dataset.site == 'facebook')
    {
      socialSelector = $('meta[name="og:image"]');
    }else if(this.dataset.site == 'twitter')
    {
      socialSelector = $('meta[name="twitter:image"]');
    }
    socialSelector.attr('content', this.parentElement.dataset.img);
    return SocialShareButton.share(this);
  });
});
