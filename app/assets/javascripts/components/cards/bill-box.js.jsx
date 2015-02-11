var BillBox = React.createClass({
  getInitialState: function(){
    return this.props;
  },

  handleSearch: function(formData, action){
    $.get(action, formData, function(data){
        this.setState( data );
    }.bind(this));
  },

  render: function(){
    return (
      <div className="contents">
        <BillCards bills={this.state.bills} />
        <FilterCard url={this.state.url} onSearch={this.handleSearch} />
      </div>
    )
  }
});