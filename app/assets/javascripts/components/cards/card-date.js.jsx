var CardDate = React.createClass({
  formatTime: function(){
    var date = new Date(this.props.date * 1000);
    var day = date.getDate();
    var month = date.getMonth();
    var year = date.getUTCFullYear();
    return "Introduced " + month + '/' + day + '/' + year; 
  },

  render: function(){
    return <p className="card--info__time">{this.formatTime()}</p>
  }
});