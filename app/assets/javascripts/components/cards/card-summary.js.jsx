var CardSummary = React.createClass({
  getInitialState: function(){
    return {summary: this.checkSummary(this.props.summary).substr(0, 250)};
  },

  checkSummary: function(string){
    return string ? string : "No Summary Provided"
  },

  setSummary: function(e){
    e.preventDefault();
    if (this.state.summary.length == 250){
      this.setState({summary: this.props.summary});  
    } else {
      this.setState({summary: this.props.summary.substr(0, 250)});
    }
  },

  toggle: function(){
    if ( this.state.summary.length == 250 ){
      return (<div> {this.checkSummary(this.props.summary).substr(0, 250)}<a className="more" href={this.props.link} onClick={this.setSummary} > ...more</a></div>);
    } else {
      return (<div> {this.checkSummary(this.props.summary)}<a className="more" href={this.props.link} onClick={this.setSummary} > ...less</a></div>);
    }
  },

  render: function(){
    return <p> {this.toggle()} </p>
  }
});