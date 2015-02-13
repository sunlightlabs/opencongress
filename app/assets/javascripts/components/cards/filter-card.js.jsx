/** @jsx React.DOM */

var FilterCard  = React.createClass({

    formHandler: function(e){
      e.preventDefault();
      var formData = $( this.refs.form.getDOMNode() ).serialize();
      this.props.onSearch( formData, this.props.url );

      this.refs.sponsor_id.getDOMNode().value = '';
    },

    render: function () {
        return (
            <aside className="filter">
              <form className="filter__search" role="search" ref="form" action={this.props.url} onSubmit={this.formHandler} >
                <div className="filter__section">
                  <div className="input-group">
                    <input type="text" className="filter__search-input" name="sponsor_id" ref="sponsor_id" placeholder="Search Activity Feed" />
                      <span className="input-group-btn">
                        <button className="filter__search-button"><span className="glyphicon glyphicon-search" onClick={this.formHandler} ></span></button>
                      </span>
                  </div>
                </div>
              </form>
            </aside>
        );
    }
});